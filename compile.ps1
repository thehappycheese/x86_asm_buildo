param (
    [string]$assembly_input_path
)

$linker_path   = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.40.33807\bin\Hostx86\x86\link.exe"

$library_path         = "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.26100.0\um\x86"
$library_files        = @("kernel32.Lib")  # Add other .lib files as needed , "user32.Lib", "gdi32.Lib"
$library_paths        = $library_files | ForEach-Object { Join-Path -Path $library_path -ChildPath $_ }
$library_paths_string = $library_paths -join ' '


if (-not $assembly_input_path) {
    Write-Error "Please provide the path to the .asm file as the first argument."
    exit 1
}
$assembly_directory  = Split-Path -Parent $assembly_input_path
$assembly_file_name  = [System.IO.Path]::GetFileNameWithoutExtension($assembly_input_path)
$out_path_object     = "$assembly_file_name.o"
$out_path_exe        = "$assembly_file_name.exe"
Write-Debug $assembly_directory
if($assembly_directory -ne ""){    
    $out_path_object = Join-Path -Path $assembly_directory -ChildPath $out_path_object
    $out_path_exe    = Join-Path -Path $assembly_directory -ChildPath $out_path_exe
}

nasm -f win32 $assembly_input_path -o $out_path_object 2>&1
if ($LASTEXITCODE -ne 0) {
    exit 1
}

& $linker_path /subsystem:console /nodefaultlib /entry:start /out:$out_path_exe $out_path_object $library_paths_string
if ($LASTEXITCODE -ne 0) {
    exit 1
}

& $out_path_exe

Write-Output "Last exit code: $LASTEXITCODE"
