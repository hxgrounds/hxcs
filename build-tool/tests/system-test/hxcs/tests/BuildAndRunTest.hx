package hxcs.tests;

import massive.munit.Assert;
import haxe.Exception;
import sys.io.Process;
import haxe.Rest;
import sys.FileSystem;
import haxe.io.Path;
import org.hamcrest.Matchers.*;

typedef Args = {
    ?haxe   : Array<String>,
    ?program: Array<String>,
    ?classpaths: Array<String>
}

class BuildAndRunTest {

    var projectDir:String;
    var buildDir:String;

    public function new() {}

    @Before
    public function setup() {
        projectDir = FileSystem.absolutePath('../../..');
        buildDir = Path.join([projectDir, 'build']);
    }


    @Test
    public function simpleExample() {
        testBuildAndRunExample("Hello", "Hello World!\n");
    }

    @Test
    public function mainClassExample() {
        testBuildAndRunExample("Main", "Main class\n");
        testBuildAndRun("Main", "Ok!\n", {
            classpaths: ["./nopackage"]
        });
    }

    @Test
    public function embeddedResourceExample() {
        var resPath  = resourcePath("resource_file.txt");

        assertThat(FileSystem.exists(resPath), is(true),
            'Resource file $resPath should exist');

        testBuildAndRunExample("EmbeddedResource", "Resource file example\n", {
            haxe: ["--resource",  '$resPath@resource_file']
        });
    }

    @Test
    public function fileSystemAccess() {
        testBuildAndRunExample("Files", "Ok\n", {
            haxe: ['--lib', 'munit', '--lib', 'hamcrest'],
            program: [buildDir]
        });
    }

// --------------------------------------------------------------------

    function resourcePath(resFile:String) {
        return Path.join(['resources', resFile]);
    }

    function testBuildAndRunExample(example: String, expectedOutput: String, ?args:Args) {
        testBuildAndRun('hxcs.examples.${example}', expectedOutput, args);
    }
    function testBuildAndRun(main: String, expectedOutput: String, ?args:Args) {
        var output = null;

        try{
            output  = buildAndRun(main, args);
        }
        catch(e){
            throw new Exception(
                'Example "$main" failed. Due to:\n\t${e}', e);
        }

        assertThat(output, equalTo(expectedOutput),
            'Output of example "$main" does not match the expected value.');
    }

    function buildAndRun(main:String, ?args: Args) {
        args = if(args == null) {} else args;

        var packageParts = main.split(".");
        var programName  = packageParts[packageParts.length - 1];

        var outDir  = transpile(main, args);
        var bin     = compile(outDir, programName);

        var programArgs = if(args.program == null) [] else args.program;

        return checkCommand(bin, programArgs);
    }

    function transpile(program:String, args:Args): String {
        var haxeArgs = if(args.haxe == null) [] else args.haxe;
        var classpaths = if(args.classpaths == null) ['.'] else args.classpaths;

        var outDir = Path.join([buildDir, 'examples', program]);
        FileSystem.createDirectory(outDir);

        var args = [
            '-cs', outDir, '-D', 'no-compilation', '--main', program, '-lib', 'hxcs'
        ].concat(haxeArgs)
        .concat(classpathArgs(classpaths));

        checkCommand('haxe', args,
            'Transpilation of haxe program $program failed'
        );

        return outDir;
    }

    function classpathArgs(classpaths:Array<String>) {
        var args = [];

        for (cp in classpaths){
            args.push('-cp');
            args.push(cp);
        }

        return args;
    }

    function compile(outDir:String, program:String): String {
        // haxelib run-dir hxcs <projectDir> hxcs_build.txt --haxe-version 4302
        //     --feature-level 1 --out ../../../build/examples/example/bin/Hello

        var build_txt = Path.join([outDir, 'hxcs_build.txt']);
        var binPath   = Path.join([outDir, 'bin', program]);

        checkCommand('haxelib', ['run-dir', 'hxcs', projectDir, build_txt, '--out', binPath]);

        if(Sys.systemName() == "Windows" || !FileSystem.exists(binPath)){
            binPath += '.exe';
        }

        assertThat(FileSystem.exists(binPath), is(true),
            'Compilation failed. Program $binPath was not genereated');

        return binPath;
    }

    function runCommand(command:String, args:Rest<String>) {
        var p = runProcess(command, args.toArray());
        var output = p.stdout.readAll().toString();

        var exitCode = p.exitCode();
        assertThat(exitCode, is(0), 'Command failed: $command, ${args.toString()}');

        return output;
    }

    function checkCommand(command:String, args:Array<String>, ?errMessage:String) {
        var p = runProcess(command, args);

        var exitCode = p.exitCode();

        if(errMessage == null){
            errMessage = 'Command ${command} ${args.join(" ")} failed';
        }

        var stdout = p.stdout.readAll().toString();

        if(exitCode != 0){
            var stderr = p.stderr.readAll().toString();
            var lines = [errMessage];

            if(stdout.length > 0){
                lines.push('[stdout]: ');
                lines.push('"$stdout"');
            }
            if(stderr.length > 0){
                lines.push('[stderr]: ');
                lines.push('"$stderr"');
            }

            Assert.fail(lines.join("\n"));
        }

        return stdout;
    }

    function runProcess(command:String, args:Array<String>) {
        return new Process(command, args);
    }
}