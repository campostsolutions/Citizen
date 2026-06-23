
import argparse
import os
import filecmp
import shutil
import zipfile
import sys
import tempfile
import subprocess
from pathlib import Path
import json

# Parse command line
parser = argparse.ArgumentParser(description='Machine configuration helper tool')
parser.add_argument('--mode', type=str, help='Specifies the usage mode. Options are: extract, merge and compare.')
parser.add_argument('--files', type=str, help='List of files to test for preCommit', required=False)
args = parser.parse_args()

scriptFolder = os.path.dirname(os.path.realpath(sys.argv[0]))
machineLibrary = os.path.join(scriptFolder, "..\\machines\\subtractive")
tempFolder = os.path.join(tempfile.gettempdir(), "tempMachineFiles")
merged = 0

if (os.path.isdir(tempFolder)):
  shutil.rmtree(tempFolder) # remove temp folder if exists
Path(tempFolder).mkdir(exist_ok=True)

#=============================================================================
def error(text):
  print("Error: " + text)
  sys.exit(1)

#=============================================================================
def setMerged():
  global merged
  merged = 1

#=============================================================================
def getDiffToolArguments(actual, expected):
  settingsFile = os.path.join(scriptFolder, "../tests/settings.json")
  data = json.load(open(settingsFile))
  diffTool = ""
  for key in data['externalDiffTools']:
    if 'default' in key and key['default'] == True:
      diffTool = key['tool'].replace("\"", "")
      diffArguments = key['args'].split()
      for i in range(len(diffArguments)):
        if diffArguments[i] == '{actual}':
          diffArguments[i] = actual
        elif diffArguments[i] == '{expected}':
          diffArguments[i] = expected
      break
  if diffTool == "":
    error(f'No default diff tool found in file "{settingsFile}" .')
  if not os.path.isfile(diffTool):
    error(f'The diff tool "{diffTool}" was not found on your machine.')

  return [diffTool] + diffArguments

#=============================================================================
def compareFiles(tempFolder, machineFile):
  tempMachineFile = os.path.join(tempFolder, os.path.basename(machineFile))
  if os.path.isfile(tempMachineFile) and os.path.isfile(machineFile):
    if not filecmp.cmp(machineFile, tempMachineFile):
      if (mode == "compare" or mode == "preCommit"):
        args = getDiffToolArguments(machineFile, tempMachineFile)
        if os.path.isfile(args[0]):
          subprocess.Popen(args) # show differences in external Diff tool
        error("DIFFERENCES DETECTED FOR FILE: " + machineFile)
      if (mode == "merge"):
        return 1 # merge required
    else:
      return 0 # no differences
  else :
    if (mode == "preCommit"):
      print("NO CORRESPONDING MACHINE/F3D FILE FOUND FOR FILE, SKIPPED FOR PRECOMMIT: " + machineFile)
    else:
      error("NO CORRESPONDING MACHINE/F3D FILE FOUND FOR FILE: " + machineFile)

#=============================================================================
def mergeFiles(srcfile, dstfile, machineFile):
  with zipfile.ZipFile(srcfile) as inzip, zipfile.ZipFile(dstfile, "w", zipfile.ZIP_DEFLATED) as outzip:
    for inzipinfo in inzip.infolist():
      with inzip.open(inzipinfo) as infile:
        if inzipinfo.filename.endswith("simulation.machine") or inzipinfo.filename.endswith("simulation.mch"):
          with open(machineFile) as f:
            content = f.read()
          outzip.writestr(inzipinfo.filename, content)
        else:
          outzip.writestr(inzipinfo.filename, infile.read())
  print("MERGING FILE: " + machineFile)
  setMerged()
  shutil.move(dstfile, srcfile)
  
#=============================================================================
def main():
  for subdir, dirs, files in os.walk(machineLibrary):
    for file in files:
      if file.endswith(".f3d"):
        if (mode == "compare" or mode == "merge" or mode == "preCommit"):
          destinationFolder = tempFolder 
        else:
          destinationFolder = subdir
        fusionFile = os.path.join(subdir, file)
        # extract machine files from f3d into desired folder
        with zipfile.ZipFile(fusionFile) as z:
          for name in z.namelist():
            if (name.endswith("simulation.machine")):
              simFile = name
              machineFile = os.path.splitext(fusionFile)[0] + '.machine'
              break
            if (name.endswith("simulation.mch")):
              simFile = name
              machineFile = os.path.splitext(fusionFile)[0] + '.mch'
              break
          try:
            with z.open(simFile) as zf, open(os.path.join(destinationFolder, os.path.basename(machineFile)), 'wb') as f:
              shutil.copyfileobj(zf, f) 
          except:
            print("THIS F3D FILE DOES NOT CONTAIN ANY MACHINE FILE : " + fusionFile)
            continue
          if (mode == "compare" or mode == "merge"):
            result = compareFiles(tempFolder, machineFile)
          if (mode == "merge"):
            tempZipFile = os.path.join(tempFolder, file)
            if (result == 1):
              mergeFiles(fusionFile, tempZipFile, machineFile)

#=============================================================================
print("### RUNNING MACHINE CONFIGURATION HELPER TOOL...")
mode = args.mode

print("### MODE: " + mode)
print("")

msg = ""
if (mode == "preCommit"):
  machinesPreCommit = args.files.split(",")
  for machine in machinesPreCommit:
    machineFile = os.path.join(os.path.join(scriptFolder, "..\\"), machine)
    if os.path.isfile(machineFile):
      main()
      compareFiles(tempFolder, machineFile)
  msg = "SUCCESS, NO DIFFERENCES DETECTED."
else:
  main() ## execute main script

  if (mode == "compare"):
    msg = "SUCCESS, NO DIFFERENCES DETECTED."
  if (mode == "extract"):
    msg = "SUCCESSFULLY EXTRACTED MACHINE FILES."
  if (mode == "merge"):
    if (merged == 1):
      msg = "SUCCESSFULLY MERGED MACHINE FILES."
    else:
      msg = "NO DIFFERENCES FOUND, MERGE IS NOT REQUIRED."

print(msg)

shutil.rmtree(tempFolder)
