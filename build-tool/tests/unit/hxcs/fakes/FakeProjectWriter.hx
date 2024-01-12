package hxcs.fakes;

import haxe.PosInfos;
import compiler.cs.compilation.preprocessing.CompilerParameters;
import compiler.cs.compilation.ProjectWriter;

import org.hamcrest.Matchers.*;

class FakeProjectWriter implements ProjectWriter {

    var hasWritten:Bool = false;

    public function new() {}

    public function writeProject(params:CompilerParameters) {
        hasWritten = true;
    }

    public function projectShouldHaveBeenWritten(?posInfo:PosInfos) {
        assertThat(hasWritten, is(true), "writeProject was not callen", posInfo);
    }
}