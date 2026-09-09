import os

def vmt_gen():
    str_file = input("file name? ")
    str_matPath = input(f"vmt directory? (default: verdessence/assets/omori/cutscenes/{str_file}) ") or f"verdessence/assets/omori/cutscenes/{str_file}"
    str_outDir = input(f"output? (default ../../../../materials/verdessence/assets/omori/cutscenes/{str_file}_frames/) ") or f"../../../../materials/verdessence/assets/omori/cutscenes/{str_file}_frames"
    str_sequence = input("frame sequence? ")

    arr_sequence = str_sequence.split()
    i_frames = set(arr_sequence)

    os.makedirs(str_outDir, exist_ok=True)

    for frames in i_frames:
        sz_vmt = f""""UnlitGeneric"
        {{
        \t"$basetexture" "{str_matPath}"
        \t"$frame" "{frames}"
        }}
        """
        str_filePath = os.path.join(str_outDir, f"{str_file}_{frames}.vmt")
        with open(str_filePath, "w") as str_vmtFile:
            str_vmtFile.write(sz_vmt)
        print(f"generated {str_filePath}")
    print("done")
    
def array_gen():
    arr_out = []
    raw_start = input("starting num (default: 0): ")
    i_start = int(raw_start) if raw_start.strip() else 0

    raw_end = input("ending num: ")
    i_end = int(raw_end)

    raw_chunk = input("per chunk (default: 3): ")
    i_chunk = int(raw_chunk) if raw_chunk.strip() else 3

    raw_iterations = input("repeats (default: 3): ")
    i_iterations = int(raw_iterations) if raw_iterations.strip() else 3
    
    for g_start in range(i_start, i_end + 1, i_chunk):
        arr_chunk = list(range(g_start, min(g_start + i_chunk, i_end + 1)))
        arr_out.extend(arr_chunk * i_iterations)
        
    str_comma = ", "
    print(", ".join(map(str, arr_out)))
    print(" ".join(map(str, arr_out)))
    print("done")
    
case = int(input("vmt gen (1) or array gen (2)? "))
if case == 1:
    vmt_gen()
elif case == 2:
    array_gen()
else:
    print("lol")