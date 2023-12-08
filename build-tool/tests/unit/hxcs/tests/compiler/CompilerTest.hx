package hxcs.tests.compiler;

import haxe.io.Path;
import hxcs.tests.compiler.BaseCompilerTests.CompilationOptions;
import proxsys.fakes.CommandMatcher.CommandSpec;


using hxcs.fakes.SystemFake.FakeFilesAssertions;
using StringTools;

class CompilerTest extends BaseCompilerTests{

    @Test
    public function createBinIfMissing() {
        fakeSys.givenPathIsMissing("bin");
        givenCompiler("mcs");

        compiler.compile(data);

        fakeSys.files.shouldBeADirectory("bin");
    }

    @Test
    public function selectCompiler() {
        test_select_compiler('mcs');
        test_select_compiler('dmcs');
        test_select_compiler('gmcs');

        //precedence
        test_select_compiler('mcs', ['mcs', 'dmcs', 'gmcs']);
        test_select_compiler('dmcs', ['dmcs', 'gmcs']);
    }

    @Test
    public function selectWindowsCompiler() {
        var winSys = {system: "Windows"};

        test_select_compiler('csc', winSys);
        test_select_compiler('csc', ['mcs', 'dmcs', 'gmcs', 'csc'], winSys);
        test_select_compiler('mcs', ['mcs', 'dmcs', 'gmcs' ], winSys);

        //find at windows dir
        for (winDir in [null, "D:\\other\\path"]){
            for (binVersion in ["64", ""]){
                var netVersion = "v4.8";
                var base = if(winDir == null) 'C:\\Windows' else winDir;

                //TO-DO: CSharpCompiler should not use both \\ and /
                var compilerPath = '$base\\Microsoft.NET\\Framework$binVersion/$netVersion/csc.exe';

                test_select_compiler(compilerPath, [compilerPath], {
                    env: ['windir'=> winDir],
                    paths: [compilerPath],
                    system: "Windows",
                    hasCompilerCheck: false
                });
            }
        }
    }

    @Test
    public function select_compiler_for_given_version() {
        var compilers_no_mcs =  ['dmcs', 'gmcs', 'smcs'];
        var compilers = ['mcs'].concat(compilers_no_mcs);

        test_select_compiler('mcs', compilers, {
            net_version: 30
        });
        test_select_compiler('dmcs', compilers_no_mcs, {
            net_version: 30
        });
        test_select_compiler('dmcs', compilers_no_mcs, {
            net_version: 30
        });
        test_select_compiler('gmcs', compilers, {
            net_version: 20
        });
        test_select_compiler('smcs', compilers, {
            net_version: 21,
            silverlight: true
        });
    }


    // -----------------------------------------------------------------------------

    function test_select_compiler(expected:String, ?existent:Array<String>, ?options:CompilationOptions) {
        setup();
        if(existent == null)
            existent = [expected];

        try {
            do_test_select_compiler(expected, existent, options);
        }
        catch(e){
            trace('Given compilers $existent, should select $expected');
            trace(e.details());
            throw e;
        }
    }
    function do_test_select_compiler(expected:String, ?existent:Array<String>, ?options:CompilationOptions) {
        if(options == null)
            options = {};
        givenOptions(options);

        expected = compilerWithExtension(expected);

        for(comp in existent){
            givenCompiler(compilerWithExtension(comp));
        }

        compiler.compile(data);

        if(options.hasCompilerCheck != false){
            shouldUseCompilerWith(expected, ['-help'], true);
        }
        shouldUseCompilerWith(expected, (cmdSpec:CommandSpec)->{
            return !cmdSpec.args.contains('-help');
        });
    }

    function compilerWithExtension(cmd:String, ?systemName:String) {
        if(systemName == null)
            systemName = this.fakeSys.systemName();

        var executable = Path.withoutDirectory(cmd);
        var ext = (Path.withoutExtension(executable) == "csc" ? "exe" : "bat");

        return (systemName == "Windows") ? Path.withExtension(cmd, ext) : cmd;
    }

}