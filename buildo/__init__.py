from __future__ import annotations
from abc import ABC
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional
import subprocess
import shlex

PathLike = str | Path

@dataclass
class BuiltO:
    exe_path:Path

    def run(self) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                self.exe_path
            ],
            cwd=self.exe_path.parent,
            capture_output=True,
            text=True
        )
    
    def run_print(self):
        app_result = self.run()
        if app_result.returncode != 0:
            print(f"Return Code: {app_result.returncode}")
        if(app_result.stderr):
            print(f"     StdErr: {app_result.stderr}")
        if(app_result.stdout):
            print(f"     StdOut: {app_result.stdout}")

@dataclass(frozen=True, slots=True)
class BuildO[T:CommandFactory, Q:CommandFactory]:

    assemblo           : T
    linko              : Q
    verbose            : bool = False
    
    def with_verbose(self, new_value:bool):
        if new_value==self.verbose:
            return self
        else:
            return self.__class__(self.assemblo, self.linko, new_value)

    def with_assemblo[F:CommandFactory](self, new_value:F) -> BuildO[F, Q]:
        if new_value==self.assemblo:
            return self
        else:
            return self.__class__(new_value, self.linko, self.verbose)
        
    def with_linko[F:CommandFactory](self, new_value:F) -> BuildO[T, F]:
        if new_value==self.linko:
            return self
        else:
            return self.__class__(self.assemblo, new_value, self.verbose)

    def run_step(self, input_path:Path, output_path:Path, command_factory:"CommandFactory"):
        command = command_factory.get_command(input_path, output_path)
        if self.verbose:
            print(f"Running: {' '.join(shlex.quote(str(item)) for item in command)}")
        result = subprocess.run(
            command,
            cwd=input_path.parent,
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            print(    f"Return Code: {result.returncode}")
            if result.stderr:
                print(f"     StdErr:\n{result.stderr}")
            if result.stdout:
                print(f"     StdOut:\n{result.stdout}")
            raise Exception(f"Build step {command_factory.__class__.__name__} failed for {input_path}")
    
    def build(self, input_assembly_file:Path|str)->BuiltO:
        input_assembly_file = Path(input_assembly_file).resolve()
        if not input_assembly_file.exists():
            raise FileNotFoundError(f"Input file {input_assembly_file} does not exist")
        if not input_assembly_file.is_file():
            raise ValueError(f"Input path {input_assembly_file} is not a file. use .build_all() instead for directories.")
        
        output_obj_file = input_assembly_file.with_suffix(".obj")
        output_exe_file = input_assembly_file.with_suffix(".exe")
        self.run_step(input_assembly_file, output_obj_file, self.assemblo)
        self.run_step(output_obj_file, output_exe_file, self.linko)
        return BuiltO(output_exe_file)

    def build_all(self, input_assembly_file:Path|str) -> list[BuiltO]:
        input_assembly_file = Path(input_assembly_file)
        if not input_assembly_file.exists():
            raise FileNotFoundError(f"Input directory {input_assembly_file} does not exist")
        if not input_assembly_file.is_dir():
            raise NotADirectoryError(f"Input path {input_assembly_file} is not a directory. use .build() instead.")
        result:list[BuiltO] = []
        for file in input_assembly_file.rglob("*.asm"):
            if file.is_file():
                result.append(self.build(file))
        if len(result)==0:
            raise Exception(f"No .asm files found in {input_assembly_file}")
        return result

@dataclass(frozen=True, slots=True)
class LibO:
    path:PathLike
    libraries:tuple[Path, ...] = field(default_factory=tuple)

    def __post_init__(self):
        path = Path(self.path)
        if not path.exists():
            raise FileNotFoundError(f"Library path {self.path} does not exist")
        if not path.is_dir():
            raise NotADirectoryError(f"Library path {self.path} is not a directory")
    
    def with_lib(self, library_name:str):
        path = Path(self.path)
        library_file_path = (path / library_name).resolve()
        if library_file_path in self.libraries:
            return self
        elif library_file_path.exists():
            #self.libraries.add(library_file_path)
            return self.__class__(self.path, (*self.libraries, library_file_path))
        else:
            # recursively search for the library in subdirectories,
            # and accept if only one match is found
            results:list[Path] = []
            for dir, _subdirs, files in path.walk():
                for file in files:
                    if file.lower() == library_name.lower():
                        results.append(dir / file)
            match results:
                case []:
                    raise FileNotFoundError(f"Library {library_name} not found in {self.path}")
                case [result]:
                    return self.__class__(self.path, (*self.libraries, result))
                case [*many_results]:
                    raise ValueError(f"Multiple libraries named {library_name} found in {self.path}:\n    {'\n    '.join(map(str, many_results))}")
        return self

    def add_libs(self, lib_names:list[str]) -> LibO:
        result = self
        for lib_name in lib_names:
            result = result.with_lib(lib_name)
        return result
    
    def merge(self, other:"LibO"):
        if Path(other.path).resolve() != Path(self.path).resolve():
            raise ValueError(f"Cannot merge libraries from different paths: {self.path} and {other.path}")
        return self.__class__(self.path, (*self.libraries, *other.libraries))
    
    

class CommandFactory(ABC):
    exe_path:PathLike
    def get_command(self, input_path:Path, output_path:Path) -> list[str|Path]: ...


@dataclass(frozen=True, slots=True)
class MSVC_Linker(CommandFactory):
    exe_path:PathLike
    entry_point:Optional[str] = None
    use_default_lib:bool = False
    libos      : tuple["LibO", ...] = field(default_factory=tuple)

    def with_libo(self, libo_to_add:"LibO"):
        new_libos:list[LibO] = []
        if len(self.libos) == 0:
            new_libos = [libo_to_add]
        else:
            was_added = False
            can_keep_same = True
            for self_libo in self.libos:
                if self_libo.path == libo_to_add.path:
                    if self_libo == libo_to_add:
                        # the whole library is the same, no change
                        new_libos.append(self_libo)
                        was_added = True
                    else:
                        # lib can be merged with existing
                        new_libos.append(libo_to_add.merge(self_libo))
                        was_added = True
                        can_keep_same = False
                else:
                    # keep existing lib
                    new_libos.append(self_libo)
            if can_keep_same and was_added:
                return self
            if not was_added:
                # add new lib
                new_libos.append(libo_to_add)
        return self.__class__(
            exe_path=self.exe_path,
            entry_point=self.entry_point,
            use_default_lib=self.use_default_lib,
            libos=tuple(new_libos)
        )

    def get_libraries(self) -> list[Path]:
        result:list[Path] = []
        for libo in self.libos:
            result.extend(libo.libraries)
        return result

    def get_command(self, input_path: Path, output_path: Path) -> list[str | Path]:
         return [
            self.exe_path,
            "/nologo",
            "/subsystem:console",
            *(["/nodefaultlib"] if not self.use_default_lib else []),
            *([f"/entry:{self.entry_point}"] if self.entry_point else []),
            f"/out:{output_path}",
            input_path,
            * self.get_libraries()
        ]


    
    def __post_init__(self):
        if not Path(self.exe_path).exists():
            raise FileNotFoundError(f"Executable path {self.exe_path} does not exist")
        if not Path(self.exe_path).is_file():
            raise ValueError(f"Executable path {self.exe_path} is not a file")

    def with_default_lib(self):
        if self.use_default_lib == True:
            return self
        return self.__class__(exe_path=self.exe_path, use_default_lib=True, entry_point=self.entry_point, libos=self.libos)
    
    def with_no_default_lib(self):
        if self.use_default_lib == False:
            return self;
        return self.__class__(exe_path=self.exe_path, use_default_lib=False, entry_point=self.entry_point, libos=self.libos)

    def with_entry_point(self, entry_point:str):
        if self.entry_point == entry_point:
            return self
        return self.__class__(exe_path=self.exe_path, use_default_lib=self.use_default_lib, entry_point=entry_point, libos=self.libos)

@dataclass(frozen=True, slots=True)
class NASM_Assembler(CommandFactory):
    exe_path:PathLike
    def get_command(self, input_path: Path, output_path: Path) -> list[str | Path]:
        return [
            self.exe_path,
            "-f", "win32",
            "-o", output_path,
            input_path
        ]

def cleanup(path:Path|str, recurse:bool=True):
    """show the user a list of .obj and .exe files, and if confirmed, delete them"""
    path = Path(path)
    if not path.exists():
        raise FileNotFoundError(f"{path} does not exist")
    if not path.is_dir():
        raise NotADirectoryError(f"{path} is not a directory")
    glob_function = path.glob
    if recurse:
        glob_function = path.rglob
    files_to_delete =(
          list(glob_function(  "*.obj"))
        + list(glob_function(  "*.exe"))
        + list(glob_function("out.txt"))
    )
    if len(files_to_delete) == 0:
        print(f"No .obj or .exe files found in {path}")
        return
    print(f"The following files will be deleted:")
    for file in files_to_delete:
        print(f"    {file}")
    result = input("Continue? [y] / n")
    if result.lower().strip() == "y" or result.strip()=="":
        for file in files_to_delete:
            file.unlink()
        print("Done")