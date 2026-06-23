#!/usr/bin/python3
#
# Script for downloading and installing binary packages that cannot be
# included as part of the source code repository.
#
# The primary repository for this script is:
# https://git.autodesk.com/fonsecr/scripts/blob/master/packages.py
#
# rene.fonseca@autodesk.com

import os
import sys
import ssl
if sys.version_info >= (3, 0):
  from http.client import HTTPSConnection
  from urllib.request import HTTPSHandler
  from urllib.error import HTTPError
  from urllib.parse import urlparse, urljoin
  import urllib.request
  urllib2 = urllib.request
else:
  from httplib import HTTPSConnection
  from urllib2 import HTTPSHandler
  from urllib2 import HTTPError
  from urlparse import urlparse, urljoin
  import urllib2
import base64
import socket
import hashlib
import platform
import zipfile
import time
import datetime
import pickle
import re
import fnmatch
import threading

debugging = False
verboseLevel = 0
strict = False
force = False
TIMEOUT = 3 # for remote connections
DEFAULT_PACKAGE_NAME = "packages.txt"
DEFAULT_CONFIG_NAME = ".packages"
INSTALL_COMPATIBILITY = 1 # update when install.db format changes

PATTERN_SHA1 = r"[0-9a-f]{40}"
PATTERN_SHA224 = r"[0-9a-f]{56}"
PATTERN_SHA256 = r"[0-9a-f]{64}"
PATTERN_SHA384 = r"[0-9a-f]{96}"
PATTERN_SHA512 = r"[0-9a-f]{128}"

PATTERN_IDENTIFIER = r"[A-Za-z_][0-9A-Za-f_]+"
PATTERN_OS = r"[a-z]+" # also used for distribution
PATTERN_OS_VERSION = r"[0-9]+([.][0-9]+)*"

supportedDigests = {"sha1": PATTERN_SHA1, "sha224":PATTERN_SHA224, "sha256":PATTERN_SHA256, "sha384":PATTERN_SHA384, "sha512":PATTERN_SHA512}

BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE = range(8)

# Returns true if the given stream supports colors (not for Windows).
def doesSupportColors(stream):
  if not hasattr(stream, "isatty"):
    return False
  if not stream.isatty():
    return False # auto color only on TTYs
  try:
    import curses
    curses.setupterm()
    return curses.tigetnum("colors") > 2
  except:
    return False

supportsColorsOutput = doesSupportColors(sys.stdout)
supportsColorsError = doesSupportColors(sys.stderr)

# Returns true if progress is supported. Do not show progress for redirected output.
def doesSupportProgress():
  result = (verboseLevel >= 0) and (supportsColorsOutput or (getOS() == "windows"))
  if result:
    if 'JENKINS_HOME' in os.environ: # easier to just skip progress when we detect Jenkins
      return False
  return result

# Class Configuration
class Config:
  def __init__(self):
    self.searchUrl = None
    self.searchUrls = []
    self.username = None
    self.password = None
    self.packagePath = "packages"
    self.key = None
    self.verbose = False
    self.silent = False
    self.strict = False
    self.force = False
    self.ignoreOS = False
    self.colors = True
    self.timeout = TIMEOUT
    self.thorough = False
    self.skipDownload = False
    self.ignoreNoLongerInUse = False
    self.variables = {}

  # Clones the config.
  def clone(self):
    result = Config()
    result.searchUrl = self.searchUrl
    result.searchUrls = self.searchUrls
    result.username = self.username
    result.password = self.password
    result.packagePath = self.packagePath
    result.key = self.key
    result.verbose = self.verbose
    result.silent = self.silent
    result.strict = self.strict
    result.force = self.force
    result.ignoreOS = self.ignoreOS
    result.colors = self.colors
    result.timeout = self.timeout
    result.thorough = self.thorough
    result.skipDownload = self.skipDownload
    result.ignoreNoLongerInUse = self.ignoreNoLongerInUse
    result.variables = self.variables.copy()
    return result

  # Validate boolean setting value.
  def validateBool(self, name, value, source=None):
    if (value == "TRUE") or (value == "FALSE"):
      return True
    if source:
      warning("Boolean setting '%s' has unexpected value '%s' for file '%s'. Only TRUE and FALSE are allowed." % (name, value, source))
    else:
      warning("Boolean setting '%s' has unexpected value '%s'. Only TRUE and FALSE are allowed." % (name, value))
    return False

  # Validate setting.
  def validate(self, name, value, source=None):
    if name in ["VERBOSE", "SILENT", "STRICT", "FORCE", "IGNORE_OS", "COLORS", "THOROUGH", "SKIP_DOWNLOAD"]:
      return self.validateBool(name, value, source=source)
    return True

  # Update setting.
  def setValue(self, name, value):
    if name == "SEARCH_URL":
      if not value.endswith("/"):
        value += "/"
      self.searchUrls.append(value)
    elif name == "USERNAME":
      self.username = value
    elif name == "PASSWORD":
      self.password = value
    elif name == "PACKAGE_PATH":
      self.packagePath = value
    elif name == "KEY":
      self.key = value
    elif name == "VERBOSE":
      self.verbose = value == "TRUE"
      if self.verbose:
        self.silent = False
    elif name == "SILENT":
      self.silent = value == "TRUE"
      if self.silent:
        self.verbose = False
    elif name == "STRICT":
      self.strict = value == "TRUE"
    elif name == "FORCE":
      self.force = value == "TRUE"
    elif name == "IGNORE_OS":
      self.ignoreOS = value == "TRUE"
    elif name == "COLORS":
      self.colors = value == "TRUE"
    elif name == "TIMEOUT":
      try:
        timeout = int(value)
        if timeout >= 0:
          self.timeout = timeout
      except:
        pass
    elif name == "THOROUGH":
      self.thorough = value == "TRUE"
    elif name == "SKIP_DOWNLOAD":
      self.skipDownload = value == "TRUE"
    elif name == "IGNORE_NO_LONGER_IN_USE":
      self.ignoreNoLongerInUse = value == "TRUE"
    else:
      self.variables[name] = value # user defined

# Define a global configuration
config = Config()

# Returns true if the url is absolute.
def isAbsoluteUrl(url):
  return bool(urlparse(url).netloc)

# Replace extension for the path.
def replaceExtension(path, extension):
  return os.path.splitext(path)[0] + extension

# Returns time prefix for verbose mode.
def getPrefix():
  if verboseLevel > 0:
    return time.strftime("%H:%M:%S") + " "
  return ""

# Encode ANSI color for the given text.
def encodeColor(text, color):
  if supportsColorsOutput and config.colors:
    return ("\x1b[1;%dm" % (30+color)) + text + "\x1b[0m"
  else:
    return text

# Writes with color to the stream.
def printWithColor(stream, text, color=None):
  if color != None:
    stream.write(encodeColor(text, color))
  else:
    stream.write(text)

# Present url.
def presentUrl(url):
  return encodeColor(url, BLUE)

# Present url with the absolute prefix in separate color.
def presentUrl2(url, absUrl):
  if not url:
    return "Unspecified"
  if url.find(absUrl) == 0:
    return encodeColor(absUrl, YELLOW) + encodeColor(url[len(absUrl):], BLUE)
  else:
    return encodeColor(url, BLUE)

root = os.getcwd()

# Present local path.
def presentPath(path):
  try:
    path = os.path.relpath(path, root)
  except:
    pass
  return encodeColor(path, BLUE)

# Present local path.
def presentPath2(path, prefix):
  path = os.path.relpath(path, root)
  prefix = os.path.relpath(prefix, root)
  if path.find(prefix) == 0:
    return encodeColor(prefix, YELLOW) + encodeColor(path[len(prefix):], BLUE)
  else:
    return encodeColor(path, BLUE)

# Write error message to standard error and stop program.
def error(text):
  if supportsColorsError and config.colors:
    text = "\x1b[1;%dm" % (30+RED) + "Error: " + text + "\x1b[0m"
    sys.stderr.write(text + "\n")
  else:
    print("Error: " + text + "\n")
  sys.exit(1)

# Write warning message.
def warning(text):
  global strict
  if strict:
    error(text)
  printWithColor(sys.stdout, "Warning: " + text + "\n", MAGENTA)

# Write normal message.
def verbose0(text):
  global verboseLevel
  if verboseLevel >= 0:
    print(text)
    # printWithColor(sys.stdout, text + "\n", YELLOW)

# Write verbose message.
def verbose1(text):
  global verboseLevel
  if verboseLevel >= 1:
    print(text)
    # printWithColor(sys.stdout, text + "\n", YELLOW)

# Write very verbose message.
def verbose2(text):
  global verboseLevel
  if verboseLevel >= 2:
    print(text)
    # printWithColor(sys.stdout, text + "\n", YELLOW)

# Returns the ID for the running OS.
def getOS():
  id = platform.system()
  if id == "Windows" or id == "Microsoft":
    return "windows"
  if id == "Darwin":
    return "osx"
  if id == "Linux":
    return "linux"
  if id == "Java":
    return "java"
  return ""

linuxDistribution = None

# Returns info about the Linux distribution.
def getLinuxDistribution():
  global linuxDistribution
  if linuxDistribution:
    return linuxDistribution

  id = None
  release = None
  codename = None

  if getOS() == "linux":
    try:
      f = open("/etc/lsb-release", "r")
    except EnvironmentError:
      f = open("/etc/redhat-release", "r")
    lines = f.readlines()
    f.close()
    for line in lines:
      i = line.find("=")
      if i >= 0:
        name = line[0:i].strip()
        value = line[i+1:].strip()
        if name == "DISTRIB_ID":
          id = value
        elif name == "DISTRIB_RELEASE":
          release = value
        elif name == "DISTRIB_CODENAME":
          codename = value
        else:
          pass
      else:
        if re.search("centos", line, re.IGNORECASE):
          id = "centos"
          i = line.find("release ")
          release = line[i+8:i+9].strip()

  linuxDistribution = (id, release, codename)
  return linuxDistribution

# Returns the distribution for the running OS.
def getOSDistribution():
  if getOS() != "linux":
    return
  id, release, codename = getLinuxDistribution()
  if not id:
    return ""
  return id.lower().split(" ")[0]

# Returns the version for the running OS.
def getOSVersion():
  os = getOS()
  if os == "osx":
    if platform.mac_ver:
      return platform.mac_ver()[0]
  if os == "linux":
    id, release, codename = getLinuxDistribution()
    if release:
      return release.lower().split(" ")[0]
  return ""

# Returns the system network name.
def getNetworkName():
  if platform.node:
    result = platform.node()
    if result[-6:] == ".local":
      return result[0:-6].lower()
    return result
  return ""

# Special case for color support under Windows.
STD_INPUT_HANDLE = -10
STD_OUTPUT_HANDLE = -11
STD_ERROR_HANDLE = -12

FOREGROUND_BLACK     = 0x0000
FOREGROUND_BLUE      = 0x0001
FOREGROUND_GREEN     = 0x0002
FOREGROUND_CYAN      = 0x0003
FOREGROUND_RED       = 0x0004
FOREGROUND_MAGENTA   = 0x0005
FOREGROUND_YELLOW    = 0x0006
FOREGROUND_GREY      = 0x0007
FOREGROUND_INTENSITY = 0x0008

BACKGROUND_BLACK     = 0x0000
BACKGROUND_BLUE      = 0x0010
BACKGROUND_GREEN     = 0x0020
BACKGROUND_CYAN      = 0x0030
BACKGROUND_RED       = 0x0040
BACKGROUND_MAGENTA   = 0x0050
BACKGROUND_YELLOW    = 0x0060
BACKGROUND_GREY      = 0x0070
BACKGROUND_INTENSITY = 0x0080

# win32 variables
COLOR_MAP = [FOREGROUND_BLACK, FOREGROUND_RED, FOREGROUND_GREEN, FOREGROUND_YELLOW, FOREGROUND_BLUE, FOREGROUND_MAGENTA, FOREGROUND_CYAN, FOREGROUND_GREY] # BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE
stdoutHandle = None
stderrHandle = None

# Handle ANSI color codes.
class Win32AnsiColorStream(object):
  def __init__(self, handle, setTextAttr):
    self.handle = handle
    self.setTextAttr = setTextAttr

  def flush(self):
    self.handle.flush()

  def write(self, _text):
    # "\x1b[1;%dm" % (30+color) + "" + "\x1b[0m"
    text = ""
    i = 0
    size = len(_text)
    while i < size:
      ch = _text[i]
      if ch == "\x1b": # escape
        if text:
          self.handle.write(text) # flush
          text = ""
        if _text[i + 1] == "[" and _text[i + 2] == "1" and _text[i + 3] == ";":
          j = _text.find("m", i + 4)
          if j >= 0:
            code = int(_text[i + 4:j]) - 30
            i = j + 1 # skip m
            if code >= 0 and code <= 7:
              self.setTextAttr(code)
          else:
            i += 4
        elif _text[i + 1] == "[" and _text[i + 2] == "0" and _text[i + 3] == "m":
          i += 4 # skip m
          self.setTextAttr(WHITE)
      else:
        text += ch
        i += 1
    if text:
      self.handle.write(text) # flush
      text = ""
    self.setTextAttr(WHITE) # restore

# Install ANSI color stream for Windows.
def installWin32Colors():
  if getOS() != "windows":
    return

  if sys.version_info >= (3, 0): # TAG: SetConsoleTextAttribute not working properly
    return

  try:
    from ctypes import windll, c_ulong, byref
  except:
    return

  global stdoutHandle
  stdoutHandle = windll.kernel32.GetStdHandle(STD_OUTPUT_HANDLE)
  global stderrHandle
  stderrHandle = windll.kernel32.GetStdHandle(STD_ERROR_HANDLE)

  try:
    SetConsoleTextAttribute = windll.kernel32.SetConsoleTextAttribute
    if not SetConsoleTextAttribute:
      return
    GetConsoleMode = windll.kernel32.GetConsoleMode
    if not GetConsoleMode:
      return
  except:
    return

  def setTextAttrOutput(color):
    SetConsoleTextAttribute(stdoutHandle, COLOR_MAP[color] + ((color != WHITE) and FOREGROUND_INTENSITY or 0))

  def setTextAttrError(color):
    SetConsoleTextAttribute(stderrHandle, COLOR_MAP[color] + ((color != WHITE) and FOREGROUND_INTENSITY or 0))

  result = c_ulong()
  if GetConsoleMode(stdoutHandle, byref(result)): # do not override for redirected handle
    sys.stdout = Win32AnsiColorStream(sys.stdout, setTextAttrOutput)
    global supportsColorsOutput
    supportsColorsOutput = True
  if GetConsoleMode(stderrHandle, byref(result)): # do not override for redirected handle
    sys.stderr = Win32AnsiColorStream(sys.stderr, setTextAttrError)
    global supportsColorsError
    supportsColorsError = True

installWin32Colors()

# Writes line to install log.
def writeInstallLog(path, text):
  try:
    f = open(os.path.join(path, "install.log"), "a")
    f.write(time.strftime("%Y-%m-%d %H:%M:%S") + " " + text + "\n")
    f.close()
  except:
    warning("Failed to write install log.")

thisOS = getOS()
thisOSDistribution = getOSDistribution()
thisOSVersion = getOSVersion()
thisNetworkName = getNetworkName()
sourcePath = None
destPath = None
sourceUrl = None
digestId = "sha256"
matchPackageUrl = None

command = "help"
if len(sys.argv) >= 2:
  command = sys.argv[1]

if command == "update":
  if len(sys.argv) >= 3:
    sourcePath = sys.argv[2]
  if len(sys.argv) >= 4:
    matchPackageUrl = sys.argv[3]
elif command == "install":
  if len(sys.argv) < 3:
    error("Need url to install package.")
  sourceUrl = sys.argv[2]
  if len(sys.argv) >= 4:
    destPath = sys.argv[3]
elif command == "uninstall":
  if len(sys.argv) < 3:
    error("Need url or unpack path to package.")
  sourcePath = sys.argv[2]
elif command == "clean":
  pass
elif command == "dump":
  if len(sys.argv) >= 3:
    matchPackageUrl = sys.argv[2]
elif command == "system":
  pass
elif command == "package":
  if len(sys.argv) < 3:
    error("Need url to package.")
  sourceUrl = sys.argv[2]
elif command == "find":
  if len(sys.argv) < 3:
    error("Need path to installed file.")
  sourcePath = sys.argv[2]
elif command == "validate":
  pass
elif command == "add":
  if len(sys.argv) < 3:
    error("Need url to add package.")
  sourceUrl = sys.argv[2]
  destPath = DEFAULT_PACKAGE_NAME
  if len(sys.argv) > 3:
    destPath = sys.argv[3]
elif command == "setconfig":
  if len(sys.argv) < 4:
    error("Need name and value to set configuration.")
  configName = sys.argv[2]
  configValue = sys.argv[3]
elif command == "digest":
  if len(sys.argv) < 3:
    error("Need path to file.")
  sourcePath = sys.argv[2]
  if len(sys.argv) > 3:
    digestId = sys.argv[3].lower()

# Workaround for SSL error. Used for Python 2.
firstSSLWarning = True
class HTTPSConnectionV3(HTTPSConnection):
  def __init__(self, *args, **kwargs):
    HTTPSConnection.__init__(self, *args, **kwargs)

  def connect(self):
    global firstSSLWarning
    sock = socket.create_connection((self.host, self.port), self.timeout)
    if self._tunnel_host:
      self.sock = sock
      self._tunnel()
    try:
      if hasattr(ssl, "PROTOCOL_SSLv23"):
        protocol = ssl.PROTOCOL_SSLv23 # aka PROTOCOL_TLS
      else:
        protocol = ssl.PROTOCOL_TLS
      if hasattr(ssl, "PROTOCOL_SSLv3"):
        protocol = ssl.PROTOCOL_SSLv3
      else:
        if firstSSLWarning:
          firstSSLWarning = False
          print("Trying TLS protocol")
      self.sock = ssl.wrap_socket(sock, self.key_file, self.cert_file, ssl_version=protocol)
    except ssl.SSLError:
      if firstSSLWarning:
        firstSSLWarning = False
        print("Trying TLS protocol")
      self.sock = ssl.wrap_socket(sock, self.key_file, self.cert_file, ssl_version=ssl.PROTOCOL_TLS)

# Workaround for SSL error. Used for Python 2.
class HTTPSHandlerV3(HTTPSHandler):
  def https_open(self, req):
    return self.do_open(HTTPSConnectionV3, req)

# Workaround to EOL bug. Used for Python 2.
firstTLSWarning = True
from functools import wraps
def sslwrap(func):
  @wraps(func)
  def bar(*args, **kw):
    global firstTLSWarning
    sslProtocol = ssl.PROTOCOL_TLSv1
    if hasattr(ssl, 'PROTOCOL_TLSv1_2'):
      sslProtocol = ssl.PROTOCOL_TLSv1_2
    else:
      if firstTLSWarning:
        firstTLSWarning = False
        warning("TLSv1.2 is not available using TLSv1")
    kw['ssl_version'] = sslProtocol
    return func(*args, **kw)
  return bar

# Returns the formatted time.
def formatTime(time):
  time = int(time)
  if time < 0:
    return "--:--:--"
  seconds = time % 60
  time = time // 60
  minutes = time % 60
  time = time // 60
  hours = time
  return "%02d:%02d:%02d" % (hours, minutes, seconds)

# Connects to the given url and returns the time.
def getServerLatency(url, username, password):
  # print("DEBUG: getServerLatency('%s')" % (url))
  startTime = time.time()
  try:
    request = urllib2.Request(url)
    if username and password:
      basicAuthorization = base64.standard_b64encode(('%s:%s' % (username, password)).encode("utf-8")).decode("utf-8")
      request.add_header("Authorization", "Basic %s" % basicAuthorization)
    response = urllib2.urlopen(request, timeout=5)
    data = response.read()
  except:
    # print("DEBUG: getServerLatency('%s'), FAILED" % (url))
    return -1 # failed
  elapsed = time.time() - startTime
  # print("DEBUG: getServerLatency('%s'), ELAPSED=%.3fs" % (url, elapsed))
  return elapsed

serversSeen = {}
serverLatencies = []

# Test latency for url.
def testServer(url, username, password):
  latency = getServerLatency(url, username, password)
  if latency >= 0: # only on success
    serverLatencies.append((latency, url))

# Test the latency for servers in the config, will set the search url to the faster server.
def testServers():
  # verbose0("Looking for the closest server...")

  if not config.searchUrls:
    return

  threads = []
  for url in config.searchUrls:
    if url in serversSeen:
      continue # do not retest
    serversSeen[url] = True
    thread = threading.Thread(target=testServer, args=(url, config.username, config.password))
    thread.start()
    threads.append(thread)

  for thread in threads:
    thread.join(config.timeout)
    if thread.is_alive():
      continue # ignore any threads that timeout

  latencies = serverLatencies
  latencies.sort()
  if False and threads:
    for latency, url in latencies:
      print("Latency: %.3fms for %s" % (latency * 1000, presentUrl(url)))
  if latencies:
    url = latencies[0][1]
    print("Closest server: " + presentUrl(url))
    config.searchUrl = url

firstProtocolWarning = True

# Download file by URL.
def downloadPackage(url, partialPath=None, allowPartial=True, username=None, password=None):
  if url.find("https://") != 0:
    global firstProtocolWarning
    if firstProtocolWarning:
      firstProtocolWarning = False
      warning("Downloading from '%s' but only HTTPS is recommended." % presentUrl(url))

  f = None
  startFrom = 0
  if allowPartial and partialPath:
    if os.path.exists(partialPath):
      f = open(partialPath, "r+b")
      f.seek(0, 2) # jump to end of file
      startFrom = f.tell()
  if debugging and (startFrom > 0):
    print("DEBUG: Partial downloaded available %d." % startFrom)

  # TAG: detect if partial download is supported by server

  basicAuthorization = None
  if username and password:
    basicAuthorization = base64.standard_b64encode(('%s:%s' % (username, password)).encode("utf-8")).decode("utf-8")

  #try:
  #  request = urllib2.Request(url + ".sha1")
  #  if basicAuthorization:
  #    request.add_header("Authorization", "Basic %s" % basicAuthorization)
  #  response = urllib2.urlopen(request)
  #  digest = response.read()
  #  if re.match(PATTERN_SHA1, digest):
  #    print("Digest: " + digest)
  #except:
  #  pass

  try:
    request = urllib2.Request(url)
    if basicAuthorization:
      request.add_header("Authorization", "Basic %s" % basicAuthorization)
    if allowPartial and (startFrom > 0):
      request.headers["Range"] = "bytes=%s-" % startFrom
    response = urllib2.urlopen(request)
  except:
    if startFrom > 0:
      verbose0("Failed to restart download at offset %d." % startFrom)
    startFrom = 0
    if f:
      f.seek(0, 0)
      f.truncate()
    request = urllib2.Request(url)
    if basicAuthorization:
      request.add_header("Authorization", "Basic %s" % basicAuthorization)
    response = urllib2.urlopen(request)

  showProgress = doesSupportProgress()
  if False:
    data = response.read()
  else:
    contentLength = None
    if "content-type" in response.headers:
      contentType = response.headers['content-type']
    if "content-length" in response.headers:
      contentLength = int(response.headers['content-length'])

    if debugging:
      if contentLength != None:
        print("DEBUG: Content length: %d" % contentLength)
      if contentType != "application/zip":
        print("DEBUG: Content type: %s" % contentType)

    if allowPartial and partialPath:
      if f and startFrom and (contentLength != None):
        if contentLength:
          verbose0("Continue from partial download '%s' at %dkb of %dkb." % (presentPath(partialPath), startFrom/1024, (startFrom + contentLength)/1024))
        else:
          f.close()
          f = None
      elif f: # start from start
        verbose0("Restarting download from beginning.")
        f.seek(0, 0)
        f.truncate()

      if not f: # new partial file
        folderPath = os.path.dirname(partialPath)
        if folderPath and not os.path.exists(folderPath):
          os.makedirs(folderPath)
        f = open(partialPath, "wb")

    EMPTY = " " * 79
    data = ""
    CHUNK_SIZE = 16 * 1024
    size = 0
    start = time.time()
    lastUpdateSize = 0
    lastUpdateTime = 0
    while True:
      chunk = response.read(CHUNK_SIZE)
      if not chunk:
        break
      if f:
        f.write(chunk)
      else:
        data += chunk
      size += len(chunk)
      if showProgress:
        now = time.time()
        if now > (lastUpdateTime + 0.5):
          elapsed2 = now - start
          bandwidth2 = (elapsed2 > 0) and size/elapsed2 or 0 # more stable for ETA
          elapsed = now - lastUpdateTime
          deltaSize = size - lastUpdateSize
          bandwidth = (elapsed > 0) and deltaSize/elapsed or 0
          lastUpdateSize = size
          lastUpdateTime = now
          if contentLength != None:
            eta = (bandwidth2 > 0) and (contentLength - size)/bandwidth2 or 0
            if eta > 24*60*60:
              eta = -1
            line2 = "Elapsed:%s Size:%s/%s Rate:%s ETA:%s" % (formatTime(now - start), "%.0fkb" % (size/1024.0), "%.0fkb" % (contentLength/1024.0), "%.0fkb/s" % (bandwidth/1024.0), formatTime(eta))
            line = "Elapsed:%s Size:%s/%s Rate:%s ETA:%s" % (encodeColor(formatTime(now - start), GREEN), encodeColor("%.0fkb" % (size/1024.0), GREEN), encodeColor("%.0fkb" % (contentLength/1024.0), GREEN), encodeColor("%.0fkb/s" % (bandwidth/1024.0), GREEN), encodeColor(formatTime(eta), GREEN))
          else:
            line2 = "Elapsed:%s Size:%s/%s Rate:%s" % ("%02d:%02d:%02d" % (hours, minutes, seconds), "%.0fkb" % (size/1024.0), "%.0fkb/s" % bandwidth)
            line = "Elapsed:%s Size:%s/%s Rate:%s" % (encodeColor("%02d:%02d:%02d" % (hours, minutes, seconds), GREEN), encodeColor("%.0fkb" % (size/1024.0), GREEN), encodeColor("%.0fkb/s" % bandwidth, GREEN))
          if len(line2) < len(EMPTY):
            line += EMPTY[len(line2):]
          setProgress(line)

  if showProgress:
    clearProgress()
  if f:
    if contentLength != None:
      finalSize = f.tell()
      expectedSize = startFrom + contentLength
      if finalSize != expectedSize:
        if debugging:
          print("DEBUG: final size: %d" % finalSize)
          print("DEBUG: expected size: %d" % expectedSize)
        error("Unexpected content for package. Got %d bytes but expected %d bytes." % (finalSize, expectedSize))
    f.close()
    return None
  return data

# Returns the digest for the given data.
def digestData(data, digest="sha256"):
  if digest == "sha1":
    d = hashlib.sha1()
  elif digest == "sha224":
    d = hashlib.sha224()
  elif digest == "sha256":
    d = hashlib.sha256()
  elif digest == "sha384":
    d = hashlib.sha384()
  elif digest == "sha512":
    d = hashlib.sha512()
  else:
    error("Invalid digest algorithm '%s'." % digest)
  d.update(data)
  return digest + ":" + d.hexdigest()

# Returns the digest for the given file. Progress is shown during.
def digestFile(path, digest="sha256"):
  showProgress = doesSupportProgress()
  EMPTY = " " * 79

  if digest == "sha1":
    d = hashlib.sha1()
  elif digest == "sha224":
    d = hashlib.sha224()
  elif digest == "sha256":
    d = hashlib.sha256()
  elif digest == "sha384":
    d = hashlib.sha384()
  elif digest == "sha512":
    d = hashlib.sha512()
  else:
    error("Invalid digest algorithm '%s'." % digest)

  try:
    size = os.path.getsize(path)
    offset = 0
    lastUpdateTime = 0

    f = open(path, "rb")
    for chunk in iter(lambda: f.read(4 * 64 * 1024), b""):
      offset += len(chunk)
      d.update(chunk)
      if showProgress:
        now = time.time()
        if now > (lastUpdateTime + 0.1):
          lastUpdateTime = now
          p = 100.0 * offset/size
          line = "Digest: " + ("%.1f%%" % p) + " " + presentPath(path[-60:])
          line += EMPTY[len(line):]
          setProgress(line)
    f.close()
  except KeyboardInterrupt:
    if showProgress:
      clearProgress()
    sys.exit(1)
  except:
    error("Failed to read file.")
  if showProgress:
    clearProgress()
  return digest + ":" + d.hexdigest()

# Load binary content.
def load(path):
  f = open(path, "rb")
  data = f.read()
  f.close()
  return data

# Save binary content to file.
def save(path, data):
  f = open(path, "wb")
  f.write(data)
  f.close()

# Unpack file to given location with progress.
def unzipPackage(packagePath, folderPath):
  verbose1("Unpacking package '%s' to '%s'" % (presentPath(packagePath), presentPath(folderPath)))
  if not os.path.isdir(folderPath):
    error("Invalid package unpack location '%s'." % folderPath)
  count = 0
  unpackedSize = 0
  lastUpdateTime = 0
  packageDescriptor = []
  EMPTY = " " * 79

  global verboseLevel
  showProgress = doesSupportProgress() and (verboseLevel < 2)

  try:
    packedSize = os.path.getsize(packagePath)
    f = zipfile.ZipFile(packagePath)

    members = f.infolist()
    totalSize = 0
    for member in members:
      totalSize += member.file_size
    total = len(members)
    makeEmptyFolders = False

    for member in members:
      if not member.filename:
        error("Invalid ZIP file.")
      if member.filename.replace(".", "") == "": # only .s
        error("Invalid ZIP file.") # allow files like ".xxx"
      if member.filename[0] == "/":
        error("Invalid ZIP file.")
      if member.filename[0] == "\\":
        error("Invalid ZIP file.")

      memberPath = os.path.normpath(os.path.join(folderPath, member.filename))
      if member.filename[-1] == "/":
        if makeEmptyFolders:
          if not os.path.exists(memberPath):
            os.makedirs(memberPath)
        continue

      memberFolder = os.path.dirname(memberPath)
      if not os.path.exists(memberFolder):
        os.makedirs(memberFolder)
      verbose2(" -> " + presentPath(memberPath))
      f.extract(member, folderPath)
      info = os.stat(memberPath)
      packageDescriptor.append((memberPath, info.st_size, info.st_mtime))
      count += 1
      unpackedSize += info.st_size

      if showProgress:
        now = time.time()
        if now > (lastUpdateTime + 0.1):
          lastUpdateTime = now
          line = presentPath(memberPath)
          shortened = False
          while len(line) > 60:
            i = max(line.find("\\"), line.find("/"))
            if i < 0:
              break
            line = line[i+1:]
            shortened = True
          d = total - count
          p = 100.0 * unpackedSize/totalSize
          line2 = ("%d" % d) + "/" + ("%.1f%%" % p) + " " + (shortened and ">" or "") + line[0:60]
          line = encodeColor(("%d" % d) + "/" + ("%.1f%%" % p), GREEN) + " " + encodeColor((shortened and ">" or "") + line[0:60], BLUE)
          line += EMPTY[len(line2):]
          setProgress(line)
          # time.sleep(0.01)

    f.close()
    if showProgress:
      clearProgress()
  except KeyboardInterrupt:
    if showProgress:
      clearProgress()
    sys.exit(1)
  except:
    if showProgress:
      clearProgress()
    error("Failed to unpack package.")

  verbose1("Installed %d files with package." % count)
  if unpackedSize > 0:
    verbose2("Package size %db/%db (compression ratio %.1f%%)." % (packedSize, unpackedSize, packedSize * 100.0/unpackedSize))
  return packageDescriptor

numberOfDownloaded = 0
numberOfInstalled = 0
downloadTime = 0
unpackTime = 0
unpackedFiles = {}

# Strip prefix of string if it starts with the prefix otherwise return the original string.
def stripPrefix(s, prefix):
  if s.startswith(prefix):
    return s[len(prefix):]
  return s

# Returns relative url.
def getRelUrl(url, config):
  if config != None:
    return stripPrefix(url, config.searchUrl)
  return url

# Parses the given text as digest. Returns tuple of digest algorithm id and the digest.
def parseDigest(value, silent=False):
  i = value.find(":")
  if i < 0:
    if silent:
      return None
    error("Unsupported digest '%s'" % value)
  digestId = value[0:i].lower()
  if not digestId in supportedDigests:
    if silent:
      return None
    error("Unsupported digest '%s'." % digestId)
  digest = value[i+1:].lower()
  if not re.match(supportedDigests[digestId], digest):
    if silent:
      return None
    error("Invalid digest '%s'." % value)
  return (digestId,  digest)

# Returns the digest from the given file.
def loadDigest(path, silent=False):
  try:
    f = open(path, "r")
    value = f.readline().strip()
    f.close()
  except:
    return None

  d = parseDigest(value, silent=silent)
  if not d:
    return d
  return d[0] + ":" + d[1]

EMPTY_PROGRESS = " " * 79

# Set progress.
def setProgress(line):
  sys.stdout.write(line + "\r")
  sys.stdout.flush()

# Clear progress.
def clearProgress():
  setProgress(EMPTY_PROGRESS)

# Returns the id for the package.
def getPackageID(path):
  # the id could come from packages.txt also
  id = os.path.relpath(path, os.path.join(config.packagePath, "downloads"))
  folder = os.path.dirname(id)
  filename = os.path.splitext(os.path.basename(id))[0]
  filename = filename.split("-")[0]
  id = os.path.join(folder, filename)
  return id

# Returns the default package ID from the given URL.
def getDefaultPackageIdByUrl(url, config):
  packageId = getRelUrl(url, config)
  i = packageId.rfind(".")
  if i >= 0:
    packageId = packageId[0:i] # strip extension
  packageId = "-".join(re.split("[-_]", packageId)[0:-1]) # strip likely version
  return packageId

# Create file of given size.
def createFileWithSize(f, size):
  if not f:
    error("Internal error.")
  if size > 0:
    f.seek(size - 1)
    f.write("\0")
  f.truncate() # in case file exceeds size

# Write block in file.
def writeFileBlock(f, offset, data):
  if not f:
    error("Internal error.")
  f.seek(offset)
  f.write(data)

class SparseFile:

  def __init__(self, f, size):
    if not f or not size:
      error("Internal error.")
    self.f = f
    self.size = size
    self.sections = []
    createFileWithSize(f, size)

  def simplify(self):
    s = self.sections
    s.sort()
    inner = 0
    o = []
    for item in s:
      value, boundary = item
      if inner == 0:
        o.append(item)
      inner += item[1]
      if inner == 0:
        o.append(item)
    self.sections = o

  def getSections(self):
    self.simplify()
    result = []
    s = self.sections
    for i in range(0, len(s), 2):
      result.append((s[i][0], s[i + 1][0]),)
    return result

  def write(self, offset, data):
    if not data:
      return
    self.sections.append((offset, -1),)
    self.sections.append((offset + len(data), 1),) # end
    self.simplify()
    writeFileBlock(self.f, offset, data)

def testSparseFile():
  print("Test sparse file")
  f = open("sparse.bin", "wb")
  sf = SparseFile(f, 15 * 1024)
  sf.write(128, "Hello World!")
  sf.write(2048, "Writer has been here.")
  sf.write(7777, "Another section.")
  sf.write(140, "Hello World!")
  f.close()

  f = open("sparse.db", "w")
  pickle.dump(sf.getSections(), f)
  f.close()

  print("Sections:" + str(sf.getSections()))
  sys.exit(1)

# Install package from url. Package is downloaded unless cached locally.
def installPackage(url, downloadPath, destPath, digest=None, configuration=None, packageId=None, folder=None):
  if not url:
    error("URL is missing.")
  if not downloadPath:
    error("Download path is missing.")
  if not url:
    error("Destination path is missing.")
  if not packageId:
    error("Package ID is missing.")

  unzipPath = destPath
  if folder:
    unzipPath = os.path.join(destPath, folder)
  if not os.path.isdir(unzipPath):
    os.makedirs(unzipPath)

  digestId = "sha256"
  _digest = None
  if digest:
    d = parseDigest(digest)
    if d:
      digestId = d[0]
      _digest = d[0] + ":" + d[1]
      del d

  fileDigest = None

  cached = False
  cachedPath = replaceExtension(downloadPath, ".cached")
  if not force and os.path.exists(downloadPath):
    # Already downloaded but could be partial download
    if True:
      digest = loadDigest(cachedPath, silent=True)
      if digest:
        if config.thorough:
          fileDigest = digestFile(downloadPath, digest=digestId) # can take some time
          if fileDigest == digest:
            cached = digest == _digest
          else:
            verbose1("Mismatching digest '%s' for package '%s'." % (fileDigest, _digest))
        else:
          cached = digest == _digest

  if cached:
    verbose1("Package has already been downloaded.")

  partialPath = replaceExtension(downloadPath, ".partial")

  if config.skipDownload:
    if not digest:
      digest = loadDigest(cachedPath, silent=True)
    if not digest:
      error("Digest could not be loaded. You need to turn on downloads.")

  if not cached and not config.skipDownload:
    # downloadPackage(url, partialPath=partialPath, username=config.username, password=config.password) # for testing
    while True: # we want to retry for primary server
      verbose1("Downloading '%s'..." % presentUrl2(url, config.searchUrl))
      try:
        start = time.time()
        data = downloadPackage(url, partialPath=partialPath, username=config.username, password=config.password)
        global downloadTime
        downloadTime += time.time() - start
        global numberOfDownloaded
        numberOfDownloaded += 1
      except KeyboardInterrupt:
        print("")
        sys.exit(1)
      except HTTPError as e:
        # alternatively use e = sys.exc_info()[1]
        if debugging:
          print(e)
        error("Failed to download package '%s' with error '%s'" % (url, e))
      except Exception as e:
        if debugging:
          print(e)
        error("Failed to download package '%s'" % url)
      break # done

    fileDigest = digestFile(partialPath, digest=digestId) # can take some time
    verbose1("Digest: %s" % fileDigest)

    if _digest:
      if fileDigest != _digest:
        error("Mismatching digest '%s' for package '%s'." % (fileDigest, _digest))

    verbose1("Storing '%s'" % presentPath(downloadPath))
    folderPath = os.path.dirname(downloadPath)
    if not os.path.exists(folderPath):
      os.makedirs(folderPath)
    try:
      if os.path.exists(downloadPath):
        os.remove(downloadPath)
      os.rename(partialPath, downloadPath)
      # save(downloadPath, data)
    except:
      error("Failed to store package '%s'" % downloadPath)

  unpackedPath = replaceExtension(downloadPath, ".unpacked")
  descriptor = None
  if cached: # only check for reinstall if we cache package
    descriptor = loadUnpackDb(unpackedPath, fail=False)
  else:
    try:
      os.remove(unpackedPath)
    except:
      pass

  db = loadInstallDb(destPath)
  unpack = True

  if cached and (descriptor != None) and (packageId in db): # check if current install is ok
    EMPTY = " " * 79
    showProgress = doesSupportProgress()
    lastUpdateTime = time.time()
    unpack = False
    current = 0
    total = len(descriptor)
    for path, size, modified in descriptor:
      current += 1
      if showProgress:
        now = time.time()
        if now > (lastUpdateTime + 0.1):
          lastUpdateTime = now
          line = presentPath(path)
          shortened = False
          while len(line) > 60:
            i = max(line.find("\\"), line.find("/"))
            if i < 0:
              break
            line = line[i+1:]
            shortened = True
          line2 = ("%d" % (total - current)) + " " + (shortened and ">" or "") + line[0:60]
          line = encodeColor("%d" % (total - current), GREEN) + " " + encodeColor((shortened and ">" or "") + line[0:60], BLUE)
          line += EMPTY[len(line2):]
          setProgress(line)
          # time.sleep(0.01)

      try:
        info = os.stat(path)
      except:
        unpack = True
        break
      if (size != info.st_size) or (modified != info.st_mtime):
        unpack = True
        break
    if showProgress:
      clearProgress()
    if unpack:
      verbose2("Unpacking required due to local change of package '%s'." % presentPath(path))

  if not unpack:
    verbose1("Skipping unpacking of package as it looks sound.")

    packageFiles = []
    for path, size, modified in descriptor:
      if os.path.basename(path) == "packages.txt":
        path = os.path.relpath(path, root)
        packageFiles.append(path)
    return packageFiles # skip unpacking

  # TAG: uninstall old versions of package
  if not config.ignoreOS:
    for _packageId in db:
      if _packageId == packageId:
        entry = getDbPackageById(db, _packageId)
        verbose0("Package '%s' with the same id detected." % presentPath(entry.url))
        #warning("Package '%s' with the same id detected." % presentPath(entry.url))
        break

  writeInstallLog(destPath, "Installed package %s from download cache %s." % (url, os.path.relpath(downloadPath, destPath)))

  start = time.time()
  descriptor = unzipPackage(downloadPath, unzipPath)
  global unpackTime
  unpackTime += time.time() - start

  try:
    f = open(unpackedPath, "wb")
    pickle.dump(descriptor, f)
    f.close()
  except KeyboardInterrupt:
    sys.exit(1)
  except:
    error("Failed to write unpack info for package.")

  if not config.skipDownload:
    if fileDigest:
      try:
        f = open(cachedPath, "w")
        f.write(fileDigest + "\n")
        f.close()
      except:
        error("Failed to write digest for downloaded package.")
    #else:
    #  error("Digest not available.")

  if True:
    totalSize = 0
    for path, size, modified in descriptor:
      totalSize += size

    entry = {}
    entry["COMPATIBILITY"] = INSTALL_COMPATIBILITY
    entry["URL"] = url
    entry["TIME"] = start
    entry["DIGEST"] = _digest
    entry["PATH"] = destPath
    entry["SOURCE"] = downloadPath
    entry["UNPACKED"] = unpackedPath
    entry["FILES"] = len(descriptor) # cached from unpacked file
    entry["SIZE"] = totalSize # cached from unpacked file
    db[packageId] = entry

    saveInstallDb(db, destPath)
    # warning("Failed to write install db.")

  for path, size, modified in descriptor:
    if path in unpackedFiles:
      if not config.ignoreOS:
        url2, size2 = unpackedFiles[path]
        warning("Package conflict detected for '%s' (size=%db) and '%s' (size=%db) with file '%s'." % (presentUrl(getRelUrl(url, config)), size, presentUrl(getRelUrl(url2, config)), size2, presentPath(path)))
    else:
      unpackedFiles[path] = (url, size)

  global numberOfInstalled
  numberOfInstalled += 1

  packageFiles = []
  for path, size, modified in descriptor:
    if os.path.basename(path) == "packages.txt":
      path = os.path.relpath(path, root)
      packageFiles.append(path)
  return packageFiles

installDBs = {} # cache for all install DBs
firstDbPath = {} # used to only print note once when install db is missing
firstInstallDbWarning = True

# Load install db from package folder.
def loadInstallDb(path=None):
  dbPath = os.path.join(path and path or config.packagePath, "install.db")

  if dbPath in installDBs:
    return installDBs[dbPath] # use cached DB

  if not os.path.exists(dbPath):
    global firstDbPath
    if not dbPath in firstDbPath:
      firstDbPath[dbPath] = True
      print("No install database found '%s'." % dbPath)
    return {}

  try:
    f = open(dbPath, "rb")
    db = pickle.load(f)
    f.close()

    for packageId in db:
      entry = db[packageId]
      if not "COMPATIBILITY" in entry or entry["COMPATIBILITY"] != INSTALL_COMPATIBILITY:
        if firstInstallDbWarning:
          firstInstallDbWarning = False
          verbose0("Install database needs to be rebuilt.")
        del db[packageId]

    installDBs[dbPath] = db
    return db
  except KeyboardInterrupt:
    sys.exit(1)
  except:
    return {}

# Save install db to package folder.
def saveInstallDb(db, path=None):
  dbPath = os.path.join(path and path or config.packagePath, "install.db")

  installDBs[dbPath] = db # update cache

  try:
    f = open(dbPath, "wb")
    pickle.dump(db, f)
    f.close()
  except KeyboardInterrupt:
    sys.exit(1)
  except:
    error("Failed to save install db.")

# Loads an unpack file.
def loadUnpackDb(path, fail=True):
  try:
    f = open(path, "rb")
    descriptor = pickle.load(f)
    f.close()
    for path, size, modified in descriptor: # check if db is valid
      pass
    return descriptor
  except KeyboardInterrupt:
    sys.exit(1)
  except:
    if fail:
      error("Failed read unpack file.")
    else:
      if debugging:
        print("DEBUG: Failed to read unpack file.")
  return None

# Sort by length operator. Used to uninstall package files.
def sortByLength(a, b):
  return len(b) - len(a)

# Uninstalls the given package.
def uninstallPackage(packageId):
  if not packageId:
    error("Package ID is missing.")

  db = loadInstallDb()

  entry = None
  if packageId in db:
    entry = getDbPackageById(db, packageId)
    del db[packageId]
  else:
    error("Package not installed.")

  if not entry.unpacked:
    error("Unpack path is missing.")

  path = os.path.normpath(os.path.join(config.packagePath, os.path.join("downloads", entry.unpacked)))
  unpackedPath = replaceExtension(path, ".unpacked")

  if not os.path.exists(unpackedPath):
    error("Package not installed.")
    return

  descriptor = loadUnpackDb(unpackedPath)

  folders = {}
  root = config.packagePath

  try:
    count = 0
    leftCount = 0
    totalSize = 0
    for path, size, modified in descriptor:

      folderPath = os.path.dirname(path)
      # add all parents
      while folderPath != root:
        if folderPath in folders:
          break
        folders[folderPath] = True
        folderPath = os.path.dirname(folderPath)

      if not os.path.exists(path):
        continue

      info = os.stat(path)
      if (size == info.st_size) and (modified == info.st_mtime):
        try:
          os.remove(path)
          verbose1("Removed file '%s'." % presentPath(path))
        except:
          error("Failed to uninstall '%s'." % presentPath(path))
        count += 1
        totalSize += size
      else:
        leftCount += 1
        # do not touch file

    folders = list(folders.keys())
    folders.sort(sortByLength)

    remainingFolders = []
    for folder in folders:
      try:
        if os.path.exists(folder):
          os.rmdir(folder)
      except:
        remainingFolders.append(folder)

    if remainingFolders:
      print("Folders remaining:")
      for folder in remainingFolders:
        print(presentPath(folder))

    if leftCount:
      print("Uninstalled %d but left %d files, freeing up %d bytes." % (count, leftCount, totalSize))
    else:
      print("Uninstalled %d files, freeing up %d bytes." % (count, totalSize))
  except KeyboardInterrupt:
    sys.exit(1)
  except:
    error("Failed to uninstall package.")

  try:
    if os.path.exists(unpackedPath):
      os.remove(unpackedPath)
  except:
    verbose0("Failed to remove unpack file.")

  saveInstallDb(db)

  writeInstallLog(config.packagePath, "Uninstalled package %s." % (packageId))

# Clean up packages no longer in use.
def cleanupPackages():

  updatePackagesRecursively(".", optional=True, configuration=config, doit=False)
  global packagesSeen

  db = loadInstallDb()

  found = False
  for packageId in db:
    entry = getDbPackageById(db, packageId)
    if not packageId in packagesSeen:
      # print("Package '%s' from '%s' no longer in use." % (packageId, presentUrl2(entry.url, config.searchUrl)))
      print("Uninstalling package '%s' from '%s'." % (packageId, presentUrl2(entry.url, config.searchUrl)))
      found = True
      uninstallPackage(packageId)

  if not found:
    print("Nothing to clean up.")

# Find installed package by package ID.
def getPackageByUrl(packageId):
  db = loadInstallDb()
  entry = getDbPackageById(db, packageId)
  #if not entry:
  #  for packageId in db:
  #    db[packageId].url
  return entry

# Installation db entry.
class InstallEntry:
  def __init__(self):
    self.url = None
    self.timestamp = None
    self.digest = None
    self.path = None
    self.source = None
    self.unpacked = None
    self.files = None
    self.size = None

# Returns entry from the install db.
def getDbPackageById(db, packageId):
  if not db or not packageId in db:
    return None

  entry = db[packageId]
  if not entry:
    return None

  result = InstallEntry()
  result.compatibility = "COMPATIBILITY" in entry and entry["COMPATIBILITY"] or 0
  result.url = "URL" in entry and entry["URL"] or None
  result.timestamp = "TIME" in entry and entry["TIME"] or None
  result.digest = "DIGEST" in entry and entry["DIGEST"] or None
  result.path = "PATH" in entry and entry["PATH"] or None
  result.source = "SOURCE" in entry and entry["SOURCE"] or None
  result.unpacked = "UNPACKED" in entry and entry["UNPACKED"] or None
  result.files = "FILES" in entry and entry["FILES"] or None
  result.size = "SIZE" in entry and entry["SIZE"] or None
  return result

# Dump information for installed package by url.
def dumpPackage(packageId):

  db = loadInstallDb()

  # TAG: if absolute url to packageId

  try:
    entry = getDbPackageById(db, packageId)
    if entry:
      print("%s:" % presentUrl2(packageId, config.searchUrl))
      if entry.url:
        print("  Url: %s" % presentUrl2(entry.url, config.searchUrl))
      if entry.timestamp:
        print("  Installed: %s" % encodeColor(datetime.datetime.fromtimestamp(entry.timestamp).strftime("%d-%m-%Y %H:%M:%S"), GREEN))
      if entry.digest:
        print("  Digest: %s" % encodeColor(entry.digest, GREEN))
      if entry.path:
        print("  Install path: %s" % presentPath(entry.path))
      if entry.files:
        print("  Files: %s" % encodeColor(str(entry.files), GREEN))
      if entry.size:
        print("  Size: %s" % encodeColor(str(entry.size), GREEN))
      if entry.source:
        print("  Source: %s" % presentPath(entry.source))
      if entry.unpacked:
        print("  Unpacked: %s" % presentPath(entry.unpacked))
    else:
      error("Package '%s' not installed." % (packageId))

    descriptor = loadUnpackDb(entry.unpacked)

    invalid = 0
    print("")
    print("Installed files:")
    for path, size, modified in descriptor:
      valid = False
      try:
        info = os.stat(path)
        valid = (size == info.st_size) and (modified == info.st_mtime)
      except:
        pass
      if not valid:
        invalid += 1

      if valid:
        print("%s %s" % (encodeColor("OK", GREEN), presentPath(path)))
      else:
        print("%s %s" % (encodeColor("FAILED", RED), presentPath(path)))

    print("")
    if invalid > 0:
      print("Found %d invalid file(s)." % invalid)
    else:
      print("All %d files seem to be fine." % len(descriptor))

  except:
    pass

# Find package by installed file.
def findPackage(_path):

  _path = os.path.normpath(os.path.join(root, _path))

  db = loadInstallDb()

  found = False
  for packageId in db:
    entry = getDbPackageById(db, packageId)
    descriptor = loadUnpackDb(entry.unpacked)

    for path, size, modified in descriptor:
      if fnmatch.fnmatch(path, _path):
        found = True
        break
    if found:
      break

  if found:
    print("File '%s' is installed by package:" % presentPath(path))
    print("  %s" % packageId)

    if entry.url:
      print("  Url: %s" % presentUrl2(entry.url, config.searchUrl))
    if entry.timestamp:
      print("  Installed: %s" % encodeColor(datetime.datetime.fromtimestamp(entry.timestamp).strftime("%d-%m-%Y %H:%M:%S"), GREEN))
    if entry.digest:
      print("  Digest: %s" % encodeColor(entry.digest, GREEN))
  else:
    print("No package found for file.")

# Checks if package is valid.
def validatePackage(path):
  descriptor = loadUnpackDb(path, fail=False)
  if not descriptor:
    return True # we cant tell

  for path, size, modified in descriptor:
    try:
      info = os.stat(path)
      if (size != info.st_size) or (modified != info.st_mtime):
        return False
    except KeyboardInterrupt:
      sys.exit(1)
    except:
      return False
  return True

# Validate installed packages.
def validatePackages():
  db = loadInstallDb()

  for packageId in db:
    entry = getDbPackageById(db, packageId)
    if not entry:
      continue
    if not validatePackage(entry.unpacked):
      print("Found invalid package '%s' from '%s'." % (packageId, presentUrl(entry.url)))
      sys.exit(1)

  print("No issues found.")
  sys.exit(0)

# Dump installed packages.
def dumpPackages(short=False):
  db = loadInstallDb()

  count = 0
  matches = 0
  if True:
    for packageId in db:

      count += 1

      global matchPackageUrl
      if matchPackageUrl:
        if not fnmatch.fnmatch(packageId, matchPackageUrl):
          if not entry.url or not fnmatch.fnmatch(entry.url, matchPackageUrl):
            continue

      if matches == 0:
        print("Packages:")
      matches += 1

      entry = getDbPackageById(db, packageId)
      if not entry:
        continue

      print("%s:" % presentUrl2(packageId, config.searchUrl))
      if entry.url:
        print("  Url: %s" % presentUrl2(entry.url, config.searchUrl))
      if entry.timestamp:
        print("  Installed: %s" % encodeColor(datetime.datetime.fromtimestamp(entry.timestamp).strftime("%d-%m-%Y %H:%M:%S"), GREEN))
      if entry.digest:
        print("  Digest: %s" % encodeColor(entry.digest, GREEN))
      if entry.path:
        print("  Install path: %s" % presentPath(entry.path))
      if entry.files:
        print("  Files: %s" % encodeColor(str(entry.files), GREEN))
      if entry.size:
        print("  Size: %s" % encodeColor(str(entry.size), GREEN))
      if entry.source:
        print("  Source: %s" % presentPath(entry.source))
      if entry.unpacked:
        print("  Unpacked: %s" % presentPath(entry.unpacked))
        print("  Status: %s" % (validatePackage(entry.unpacked) and encodeColor("OK", GREEN) or encodeColor("FAILED", RED)))
      print("")

    if count == 0:
      print("No packages found.")
    else:
      print("Found %d out of %d packages." % (matches, count))

# Add package for current folder.
def addPackage(url, path=DEFAULT_PACKAGE_NAME):
  testServers()

  absurl = urljoin(config.searchUrl, url)
  if not isAbsoluteUrl(absurl):
    error(f"Could not resolve URL {absurl}.")
  verbose1("Downloading '%s'..." % presentUrl2(absurl, config.searchUrl))
  try:
    data = downloadPackage(absurl, username=config.username, password=config.password)
  except KeyboardInterrupt:
    sys.exit(1)
  except:
    error("Failed to download package '%s'" % absurl)

  import io
  memoryFile = io.BytesIO(data)
  try:
    zip = zipfile.ZipFile(memoryFile)
    if zip.testzip() != None:
      error("Package is not a ZIP file.")
  except:
    error("Package is not a ZIP file.")

  relurl = absurl
  if relurl.find(config.searchUrl) == 0:
    relurl = relurl[len(config.searchUrl):]
  digest = digestData(data)
  print(">>> FRAGMENT <<<")

  line = "PACKAGE %s OS=%s" % (presentUrl2(relurl, config.searchUrl), encodeColor(thisOS, GREEN))
  if thisOSDistribution:
    line += " DIST=%s" % encodeColor(thisOSDistribution, GREEN)
  if thisOSVersion:
    line += " VERSION=%s" % encodeColor(thisOSVersion, GREEN)
  line += " DIGEST=%s" % encodeColor(digest, GREEN)
  print(line)

  line = "PACKAGE %s OS=%s" % (relurl, thisOS)
  if thisOSDistribution:
    line += " DIST=%s" % thisOSDistribution
  if thisOSVersion:
    version = thisOSVersion
    i = version.find(".")
    if i > 0: # not if first
      version = version[0:i] + ".*" # only use major version by default
    line += " VERSION=%s" % version
  line += " DIGEST=%s" % digest
  try:
    f = open(path, "a")
    f.write(line + "\n")
    f.close()
  except:
    error("Failed to add package.")

visitedPaths = {} # detect cyclic dependencies
packagesSeen = {} # detect multiple references to the same package

# Updates packages according to package definition files.
def updatePackagesRecursively(folderPath, optional=False, configuration=Config(), doit=True, level=0):
  subConfig = configuration.clone()

  if os.path.isdir(folderPath):
    path = os.path.join(folderPath, DEFAULT_PACKAGE_NAME)
  else:
    path = folderPath
    folderPath = os.path.dirname(path)

  if not os.path.exists(path):
    if not optional:
      error("Package file not found '%s'." % path)
    return # nothing to do

  if path in visitedPaths:
    warning("Cyclic dependency detected for '%s'." % path)
    return
  visitedPaths[path] = True

  f = open(path, "r")
  lines = f.readlines()
  f.close()
  for line in lines:
    i = line.find("#")
    if i >= 0:
      line = line[0:i]
    line = line.strip()
    if not line:
      continue
    fields = line.split(" ")
    if not fields:
      continue
    action = fields[0]

    if action == "ECHO":
      #if len(fields) < 2:
      #  error("ECHO action is missing text.")

      text = " ".join(fields[1:]).strip()
      if text:
        m = re.match(r'^"([^"]*)"$', text)
        if not m:
          error("Invalid string '%s' for ECHO." % text)
        text = m.group(1) # without quotes
      result = ""
      i = 0
      for m in re.finditer(r"\$\{[^{}]+\}", text):
        result += text[i:m.start()]
        i = m.end()
        name = m.group(0)[2:-1]
        value = ""
        if name in subConfig.variables:
          value = subConfig.variables[name]
        result += value
      result += text[i:]

      verbose0(encodeColor("ECHO", GREEN) + ("[%s]: " % folderPath) + encodeColor(result, MAGENTA))

    elif action == "SLEEP":
      text = " ".join(fields[1:]).strip()
      try:
        delay = float(text)
      except:
        error("Invalid time '%s' for SLEEP." % text)
      verbose0(encodeColor("SLEEP", GREEN) + ("[%s]: " % folderPath) + encodeColor(str(delay) , MAGENTA))
      if not subConfig.silent: # only if not silent
        time.sleep(delay)

    elif action == "SET":
      if len(fields) < 2:
        error("SET action is missing NAME=VALUE.")
      nv = fields[1].split("=")
      if len(nv) != 2:
        error("Invalid syntax for SET action.")
      name = nv[0]
      value = nv[1]
      if name == "SEARCH_URL": # make absolute to current url
        value = urljoin(subConfig.searchUrl, value)
      elif name == "PACKAGE_PATH": # make absolute to current folder
        value = os.path.normpath(os.path.join(os.getcwd(), os.path.join(folderPath, value)))
      if subConfig.validate(name, value):
        subConfig.setValue(name, value)

      verbose1(encodeColor("SET", GREEN) + ("[%s]: " % folderPath) + encodeColor(name + "=" + value, MAGENTA))

    elif action == "INCLUDE":
      if len(fields) < 2:
        error("INCLUDE action is missing path.")
      if fields[1] == ".":
        error("INCLUDE action does not allow self inclusion.")
      subpath = os.path.normpath(os.path.join(folderPath, fields[1]))

      verbose1(encodeColor("INCLUDE", GREEN) + ("[%s]: " % folderPath) + encodeColor(subpath, MAGENTA))

      updatePackagesRecursively(subpath, optional=False, configuration=subConfig, level=level+1)

    elif action == "PACKAGE":
      if len(fields) < 2:
        error("PACKAGE action is missing URL.")
      actionPath = fields[1]
      aliasPath = actionPath
      if actionPath.find("|") >= 0:
        aliasPath = actionPath.split("|", 1)[1] # strip prefix
        actionPath = "".join(actionPath.split("|")) # strip |

      url = urljoin(subConfig.searchUrl, actionPath)
      if not isAbsoluteUrl(url):
        error(f"Could not resolve URL {url}.")

      if aliasPath.find("://") >= 0:
        aliasPath = aliasPath.split("://", 1)[1] # strip protocol
      while True: # remove relative paths
        if aliasPath.startswith("../"):
          aliasPath = aliasPath[3:] # strip relative path
        elif aliasPath.startswith("./"):
          aliasPath = aliasPath[2:] # strip relative path
        else:
          break

      packageId = None
      operatingSystem = None
      distribution = None
      version = None
      networkName = None
      key = None
      digest = None
      condition = None
      priority = (level == 0) and 100 or 0 # give main definition higher priority by default
      folder = None # TAG: allow redirect within package folder

      for f in fields[2:]: # skip PACKAGE and URL
        nv = f.split("=")
        name = None
        value = None
        if len(nv) == 1:
          name = nv[0]
        elif len(nv) == 2:
          name = nv[0]
          value = nv[1]
        else:
          error("Invalid syntax in package file.")

        if not name:
          error("Identifier missing for '%s'." % f)
        if not re.match(PATTERN_IDENTIFIER, name):
          error("Invalid identifier '%s'." % name)

        if name == "ID":
          if not re.match(PATTERN_IDENTIFIER, value):
            error("Invalid package ID '%s'." % value)
          packageId = value
        elif name == "OS":
          if not re.match(PATTERN_OS, value):
            error("Invalid operating system '%s'." % value)
          operatingSystem = value
        elif name == "DIST":
          if not re.match(PATTERN_OS, value):
            error("Invalid OS distribution '%s'." % value)
          distribution = value
        elif name == "VERSION":
          if not re.match(PATTERN_OS_VERSION, value):
            error("Invalid OS version '%s'." % value)
          version = value
        elif name == "ALIAS":
          # if not re.match(PATTERN_ALIAS, value):
          #  error("Invalid alias '%s'." % value)
          folder = value
        elif name == "NAME":
          networkName = value
        elif name == "KEY":
          key = value
        elif name == "CONDITION":
          condition = value
        elif name == "DIGEST":
          d = parseDigest(value)
          if not d:
            error("Invalid digest '%s'." % value)
          digest = d[0] + ":" + d[1]
        elif name == "PRIORITY":
          try:
            priority = int(value) # TAG: use priority to resolve conflicts
          except:
            error("Invalid package priority '%s'." % value)

      global matchPackageUrl
      if matchPackageUrl:
        if not fnmatch.fnmatch(url, matchPackageUrl):
          continue
      if operatingSystem and not subConfig.ignoreOS:
        if operatingSystem != thisOS:
          if doit:
            verbose1(encodeColor("PACKAGE", GREEN) + "[%s]: %s skipping by OS '%s' != '%s'" % (folderPath, presentUrl2(url, subConfig.searchUrl), operatingSystem, thisOS))
          continue
      if distribution and not subConfig.ignoreOS:
        if distribution != thisOSDistribution:
          if doit:
            verbose1(encodeColor("PACKAGE", GREEN) + "[%s]: %s skipping by DIST '%s' != '%s'" % (folderPath, presentUrl2(url, subConfig.searchUrl), distribution, thisOSDistribution))
          continue
      if version and not subConfig.ignoreOS:
        if not fnmatch.fnmatch(thisOSVersion, version):
          if doit:
            verbose1(encodeColor("PACKAGE", GREEN) + "[%s]: %s skipping by VERSION '%s' != '%s'" % (folderPath, presentUrl2(url, subConfig.searchUrl), version, thisOSVersion))
          continue
      if networkName:
        if not fnmatch.fnmatch(thisNetworkName, networkName):
          if doit:
            verbose1(encodeColor("PACKAGE", GREEN) + "[%s]: %s skipping by NETWORKNAME '%s' != '%s'" % (folderPath, presentUrl2(url, subConfig.searchUrl), networkName, thisNetworkName))
          continue
      if key:
        if key != subConfig.key:
          if doit:
            verbose1(encodeColor("PACKAGE", GREEN) + "[%s]: %s skipping by KEY '%s' != '%s'" % (folderPath, presentUrl2(url, subConfig.searchUrl), key, subConfig.key))
          continue
      if condition:
        conditions = condition.split(",")
        found = False
        for c in conditions:
          if c in subConfig.variables:
            found = True
            break
        if not found:
          if doit:
            verbose1(encodeColor("PACKAGE", GREEN) + "[%s]: %s skipping by CONDITION '%s'" % (folderPath, presentUrl2(url, subConfig.searchUrl), condition))
          continue

      if folder:
        aliasPath = os.path.normpath(os.path.join(folder, aliasPath))

      downloadPath = os.path.normpath(os.path.join(subConfig.packagePath, os.path.join("downloads", aliasPath)))
      destPath = os.path.normpath(subConfig.packagePath)

      if doit:
        print(getPrefix() + encodeColor("PACKAGE", GREEN) + "[%s]: %s -> %s" % (folderPath, presentUrl2(url, subConfig.searchUrl), presentPath(destPath)))

      if not packageId:
        packageId = getDefaultPackageIdByUrl(url, config)
      if packageId in packagesSeen:
        _path, _priority = packagesSeen[packageId]
        if priority < _priority:
          doit = False
        else:
          warning("The same package '%s' is referenced more than once with priority %d." % (packageId, priority))
      packagesSeen[packageId] = (path, priority)

      if doit:
        packageFiles = installPackage(url, downloadPath, destPath, digest=digest, configuration=subConfig, packageId=packageId, folder=folder)

        if packageFiles:
          for path in packageFiles:
            verbose1(encodeColor("INCLUDE", GREEN) + ("[%s]: " % folderPath) + encodeColor(path, MAGENTA))
            updatePackagesRecursively(path, optional=False, configuration=subConfig, level=level+1)
    else:
      verbose0("Ignoring line '%s'" % line)

# Updates packages.
def updatePackages(folderPath, optional=False):
  testServers()
  updatePackagesRecursively(folderPath, optional=optional, configuration=config)

  db = loadInstallDb()
  if True:
    for packageId in db:
      if not packageId in packagesSeen:
        entry = getDbPackageById(db, packageId)
        if not config.ignoreNoLongerInUse:
          print("Package '%s' from '%s' no longer in use." % (presentUrl2(packageId, config.searchUrl), presentUrl2(entry.url, config.searchUrl)))

  if verboseLevel >= 0:
    if (numberOfDownloaded == 0) and (numberOfInstalled == 0):
      print("All seems to be just fine.")
    else:
      print("Packages downloaded: %d" % numberOfDownloaded)
      print("Packages installed: %d" % numberOfInstalled)

# Prints the digest for the given file.
def makeDigest(path, digest="sha256"):
  d = digestFile(path, digest)
  print(d)

# Set configuration setting.
def setConfig(name, value):
  loadConfig()

  globalPath = DEFAULT_CONFIG_NAME
  entries = {}
  if config.searchUrl:
    entries["SEARCH_URL"] = config.searchUrl
  if config.packagePath:
    entries["PACKAGE_PATH"] = config.packagePath
  if config.key:
    entries["KEY"] = config.key
  if config.verbose:
    entries["VERBOSE"] = config.verbose and "TRUE" or "FALSE"
  if config.silent:
    entries["SILENT"] = config.silent and "TRUE" or "FALSE"
  if config.strict:
    entries["STRICT"] = config.strict and "TRUE" or "FALSE"
  if config.force:
    entries["FORCE"] = config.force and "TRUE" or "FALSE"
  if config.ignoreOS:
    entries["IGNORE_OS"] = config.ignoreOS and "TRUE" or "FALSE"
  if config.colors:
    entries["COLORS"] = config.colors and "TRUE" or "FALSE"
  if config.timeout > 0:
    entries["TIMEOUT"] = str(config.timeout)
  if config.skipDownload:
    entries["SKIP_DOWNLOAD"] = config.skipDownload and "TRUE" or "FALSE"
  if config.ignoreNoLongerInUse:
    entries["IGNORE_NO_LONGER_IN_USE"] = config.ignoreNoLongerInUse and "TRUE" or "FALSE"
  if config.thorough:
    entries["THOROUGH"] = config.thorough and "TRUE" or "FALSE"
  if name in entries:
    if entries[name] == value:
      return # nothing to do
  entries[name] = value
  try:
    f = open(globalPath, "w")
    for name in config:
      f.write(name + "=" + config[name] + "\n")
    f.close()
  except:
    error("Failed to write global configuration '%s'." % globalPath)

# Returns the folder of the script.
def getScriptPath():
  return os.path.dirname(os.path.realpath(sys.argv[0]))

# Load configuration, will be a global variable.
def loadConfig():
  scriptFolder = getScriptPath()

  # could have option to choose which folder to use
  paths = [
    os.path.expanduser("~/" + DEFAULT_CONFIG_NAME)
  ]
  if (scriptFolder and (scriptFolder != ".")):
    paths.append(os.path.join(scriptFolder, DEFAULT_CONFIG_NAME))
  paths.append(DEFAULT_CONFIG_NAME)
  if (scriptFolder and (scriptFolder != ".")):
    paths.append(os.path.join(scriptFolder, DEFAULT_CONFIG_NAME + "_user")) # allows override not in the repository
  paths.append(DEFAULT_CONFIG_NAME + "_user") # allows override not in the repository

  for path in paths:
    if not os.path.exists(path):
      continue

    lines = []
    try:
      f = open(path, "r")
      lines = f.readlines()
      f.close()
    except:
      error("Failed to read global configuration '%s'." % path)

    for line in lines:
      i = line.find("#")
      if i >= 0:
        line = line[0:i]
      line = line.strip()
      if not line:
        continue
      nv = line.split("=")
      if len(nv) == 2:
        name = nv[0]
        value = nv[1]
        if name == "SEARCH_URL": # make absolute to current url
          value = urljoin(config.searchUrl, value)
          if not isAbsoluteUrl(value):
            error("Cannot resolve SEARCH_URL to absolute URL for '%s'." % path)
        elif name == "PACKAGE_PATH": # make absolute to current folder
          value = os.path.normpath(os.path.join(os.getcwd(), value))
        if config.validate(name, value, source=path):
          config.setValue(name, value)
      else:
        error("Invalid syntax in configuration file '%s' for line '%s'." % (path, line))

  global verboseLevel
  verboseLevel = max(verboseLevel, config.verbose and 1 or 0)
  if config.silent:
    verboseLevel = -1
  global strict
  strict = config.strict
  global force
  force = config.force

# Dump configuration.
def dumpConfig():
  settings = []
  settings.append(("Search URL", config.searchUrl and config.searchUrl or "NOT DEFINED"))

  if config.searchUrls:
    for url in config.searchUrls:
      settings.append(("Search URLs", url))

  settings.append(("Username", config.username and config.username or "NOT DEFINED"))
  settings.append(("Password", config.password and config.password or "NOT DEFINED"))
  settings.append(("Package path", config.packagePath and config.packagePath or "NOT DEFINED"))
  settings.append(("Key", config.key and config.key or "NOT DEFINED"))
  settings.append(("Verbose", config.verbose and "TRUE" or "FALSE"))
  settings.append(("Silent", config.silent and "TRUE" or "FALSE"))
  settings.append(("Strict", config.strict and "TRUE" or "FALSE"))
  settings.append(("Force", config.force and "TRUE" or "FALSE"))
  settings.append(("Ignore OS", config.ignoreOS and "TRUE" or "FALSE"))
  settings.append(("Colors", config.colors and "TRUE" or "FALSE"))
  settings.append(("Timeout", str(config.timeout)))
  settings.append(("Thorough", config.thorough and "TRUE" or "FALSE"))
  settings.append(("Skip download", config.skipDownload and "TRUE" or "FALSE"))
  settings.append(("Ignore no longer in use", config.ignoreNoLongerInUse and "TRUE" or "FALSE"))
  for name, value in settings:
    print(encodeColor(name, BLUE) + ": " + encodeColor(value, GREEN))

# Dump system info.
def dumpSystem():
  settings = []
  settings.append(("Operating system", thisOS and thisOS or "Unknown"))
  settings.append(("Distribution", thisOSDistribution and thisOSDistribution or "Not applicable"))
  settings.append(("Version", thisOSVersion and thisOSVersion or "Not applicable"))
  settings.append(("Network name", thisNetworkName and thisNetworkName or "Unknown"))
  for name, value in settings:
    print(encodeColor(name, BLUE) + ": " + encodeColor(value, GREEN))

# Dump help.
def help():
  print("Usages:")
  print("")
  print("package.py update [CONFIG PATH] [PATTERN]")
  print("  Updates the packages according with the packages configuration packages.txt.")
  print("")
  print("package.py add URL [CONFIG PATH]")
  print("  Adds the given package to the packages configuration packages.txt.")
  print("")
  print("package.py install URL [DEST]")
  print("  Installs the package at the given location.")
  print("")
  print("package.py uninstall SOURCE")
  print("  Uninstalls the package using the given unpacked file.")
  print("")
  print("package.py clean")
  print("  Clean up installed packages.")
  print("")
  print("package.py config")
  print("  Dumps the configuration file.")
  print("")
  print("package.py system")
  print("  Dumps the system information.")
  print("")
  print("package.py setconfig NAME VALUE")
  print("  Sets the given setting in the configuration file.")
  print("")
  print("package.py digest PATH")
  print("  Calculates the digest for the given file.")
  print("")
  print("packages.py dump [PATTERN]")
  print("  Dump installed packages.")
  print("")
  print("packages.py package URL")
  print("  Dump info on installed package.")
  print("")
  print("packages.py find PATH")
  print("  Find the package for the given file.")

def initialize():
  if sys.version_info < (3, 0):
    import urllib2
    ssl.wrap_socket = sslwrap(ssl.wrap_socket)
    urllib2.install_opener(urllib2.build_opener(HTTPSHandlerV3()))

# Run Script
start = time.time()
initialize()
loadConfig()

if command == "install":
  filename = urlsplit(sourceUrl)[3]
  if not filename:
    error("Could not derive filename from URL.")
  downloadPath = os.path.normpath(os.path.join(config.packagePath, os.path.join("downloads", filename)))
  if not destPath:
    destPath = config.packagePath
  installPackage(sourceUrl, downloadPath, destPath)
elif command == "uninstall":
  uninstallPackage(sourcePath)
elif command == "clean":
  cleanupPackages()
elif command == "update":
  updatePackages(sourcePath and sourcePath or ".", optional=not sourcePath)
elif command == "dump":
  dumpPackages()
elif command == "package":
  dumpPackage(sourceUrl)
elif command == "find":
  findPackage(sourcePath)
elif command == "validate":
  validatePackages()
elif command == "add":
  addPackage(sourceUrl, path=destPath)
elif command == "config":
  dumpConfig()
elif command == "system":
  dumpSystem()
elif command == "setconfig":
  setConfig(configName, configValue)
elif command == "digest":
  makeDigest(sourcePath, digestId)
elif command == "help":
  help()
else:
  error("Unsupported command.")

if command in ["install", "update", "add"]:
  now = time.time()
  elapsed = now - start
  verbose1("Elapsed time %s" % datetime.timedelta(seconds=elapsed))
  if numberOfDownloaded > 0:
    verbose1("Download time %s (%.1f%%)" % (datetime.timedelta(seconds=downloadTime), downloadTime/elapsed * 100))
  if numberOfInstalled > 0:
    verbose1("Unpack time %s (%.1f%%)" % (datetime.timedelta(seconds=unpackTime), unpackTime/elapsed * 100))
