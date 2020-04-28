## FileLogger

import os
import json

type
  J_Thing = object of RootObj
    name: string
    size: BiggestInt
  J_File = object of J_Thing
    ext: string
  J_Folder = object of J_Thing
    folders: seq[J_Folder]
    files: seq[J_File]

proc get_folder(dir: string): J_Folder =
  result = J_Folder(name:lastPathPart(dir))
  for kind, path in walkDir(dir):
    case kind:
      of pcDir:
        let subdir = get_folder(path)
        result.folders.add(subdir)
        result.size += subdir.size
      of pcFile:
        let (dir, name, ext) = splitFile(path)
        let size = getFileSize(path)
        result.files.add(J_File(name:name, ext:ext, size:size))
        result.size += size
      else: discard

proc save_as_json(folder: J_Folder; pretty = true) =
  if (pretty): writeFile(folder.name & "_data.json", (%*folder).pretty())
  else: writeFile(folder.name & "_data.json", $(%*folder))