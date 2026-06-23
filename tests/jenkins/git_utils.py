import os
import sys
import subprocess

scriptFolder = os.path.dirname(os.path.realpath(sys.argv[0]))
libraryFolder = os.path.join(scriptFolder, "..")

def runGit(args, textStdout=True):
  """
  Run a git command.
  
  args: git command split into a list of string arguments
  textStdout: Convert stdout and stderr to UTF-8 string if true, Bytes if false
  
  returns tuple of (process return code, stdout, stderr)
  """
  encoding = None
  if textStdout:
    encoding = "utf8"

  process = subprocess.Popen(args, encoding=encoding, text=textStdout, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
  try:
    out = process.stdout.read()
    err = process.stderr.read()
    code = process.wait()
    return (code, out, err)
  except KeyboardInterrupt:
    process.terminate()

def readFileFromCommit(commitish, file):
  """ 
  Read in file as it exists in git at commitish

  Returns a tuple containing the file as Bytes, error code from the git command, and any errors that
  occured.
  """
  code = 0
  out = ""
  err = ""
  relPath = os.path.relpath(file, libraryFolder).replace('\\', "/")
  # retry command a few times
  for x in range(10):
    # git cat-file --filters respects autocrlf setting
    code, out, err = runGit(["git", "-C", libraryFolder, "cat-file", "--filters", f"{commitish}:{relPath}"], False)
    if code == 0:
      break
  return (out, code, err)

def getGitLog(filePath):
  '''
  Returns the git commit log for the given file. The returned object is a list of commit hashes
  '''
  # need path relative to repository root
  relPath = os.path.relpath(filePath, libraryFolder)
  code, data, err = runGit(["git", "-C", libraryFolder, "log", "--since", "2013-9-01", "--pretty=format:%H", relPath])
  if code != 0:
    return

  entries = []
  lines = data.split("\n")
  for line in lines:
    if not line:
      continue
    line = line.strip()
    if not line:
      continue
    entries.append(line)
  return entries
