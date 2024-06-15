from pathlib import Path
from dataclasses import dataclass, field
from typing import Protocol
import subprocess

PathLike = str | Path

@dataclass
class BuiltO:
    exe_path:Path

    def run(self)->subprocess.CompletedProcess:
        return subprocess.run([self.exe_path], capture_output=True, text=True)
    
    def run_print(self):
        app_result = self.run()
        if app_result.returncode != 0:
            print(f"Return Code: {app_result.returncode}")
        if(app_result.stderr):
            print(f"     StdErr: {app_result.stderr}")
        if(app_result.stdout):
            print(f"     StdOut: {app_result.stdout}")

@dataclass
class BuildO:

    assemblo           : "RunO"
    linko              : "RunO"
    _entry_point       : str = "start"
    _include_lib_paths : list[Path] = field(default_factory=list)
    _include_libs      : list[Path] = field(default_factory=list)


    def add_lib_path(self, lib_path:PathLike):
        lib_path = Path(lib_path)
        if lib_path.exists():
            self._include_lib_paths.append(lib_path)
        else:
            raise FileNotFoundError(f"Library path {lib_path} does not exist")
        return self

    def add_lib(self, lib_name:str):
        """search for the library in each of the library paths added using [Buildo.add_lib_path]"""
        for lib_path in self._include_lib_paths:
            lib_path = lib_path / lib_name
            if lib_path.exists():
                self._include_libs.append(lib_path)
                return self
        raise FileNotFoundError(f"Library {lib_name} not found in any of the library paths")
    
    def set_entry_point(self, entry_point:str):
        self._entry_point = entry_point
        return self
    
    def get_entry_point(self):
        return self._entry_point

    def get_libraries(self):
        return self._include_libs
    
    def _build_inner(self, input_assembly_file:Path)->BuiltO:
        output_obj_file = input_assembly_file.with_suffix(".obj")
        output_exe_file = input_assembly_file.with_suffix(".exe")
        self.assemblo.run(input_assembly_file, output_obj_file, self)
        self.linko.run(output_obj_file, output_exe_file, self)
        return BuiltO(output_exe_file)

    def build(self, input_assembly_file:Path|str) -> list[BuiltO]:
        input_assembly_file = Path(input_assembly_file)
        if not input_assembly_file.exists():
            raise FileNotFoundError(f"Input file {input_assembly_file} does not exist")
        result = []
        if input_assembly_file.is_dir():
            for file in input_assembly_file.rglob("*.asm"):
                if file.is_file():
                    result.append(self._build_inner(file))
        else:
            result.append(self._build_inner(input_assembly_file))
        return result
        


class ArgumentFactory(Protocol):
    """takes a BuildO and produces a list of string arguments used by a subclass of LinkO / AssemblO"""
    def build_arguments(self, input_path:Path, output_path:Path, buildo:BuildO) -> list[str|Path]: ...

class RunO:
    exe_path:Path
    arg_factory:ArgumentFactory
    def __init__(self, exe_path:PathLike, arg_factory:ArgumentFactory):
        self.exe_path = Path(exe_path)
        self.arg_factory = arg_factory
    
    def run(self, input_path:Path, output_path:Path, buildo:BuildO):
        return subprocess.run(
            [
                self.exe_path,
                *self.arg_factory(input_path, output_path, buildo)
            ],
            capture_output=True,
            text=True
        )

class MSVC_Linker(RunO):
    def __init__(self, exe_path:PathLike):
        def build_args(input_path:Path, output_path:Path, buildo:BuildO)->list[str]:
            return [
                "/nologo",
                "/nodefaultlib",
                "/subsystem:console",
                f"/entry:{buildo.get_entry_point()}",
                f"/out:{output_path}",
                input_path,
                * buildo.get_libraries()
            ]
        super().__init__(exe_path, build_args)

class NASM_Assembler(RunO):
    def __init__(self, exe_path:PathLike):
        def build_args(input_path:Path, output_path:Path, buildo:BuildO)->list[str]:
            return [
                "-f", "win32",
                "-o", output_path,
                input_path
            ]
        super().__init__(exe_path, build_args)
    
    