# vim: sw=2 sts=2

# for cmake: set(CMAKE_EXPORT_COMPILE_COMMANDS "ON")

import glob
import os.path
import sys

thisDir = os.path.abspath( os.path.dirname( __file__ ) )

def Settings( **kwargs ):
  language = kwargs[ 'language' ]
  if language == 'cfamily':
    pattern1 = os.path.join(thisDir, 'build', 'compile_commands.json')
    pattern2 = os.path.join(thisDir, 'build-*', 'compile_commands.json')
    candidates = glob.glob(pattern1) + glob.glob(pattern2)

    if candidates:
      cmake_commands = max(candidates, key=os.path.getmtime)
    else:
      cmake_commands = pattern1
    if os.path.exists( cmake_commands ):
      return {
        'ls': {
          'compilationDatabasePath': os.path.dirname( cmake_commands )
        }
      }
    else:
      return {
        'flags': [
            '-x', 'c++', '-std=c++17',
            '-Wall', '-Wextra', '-Werror', '-Wpedantic',
            '-I.', '-Iinclude',
            '-Isrc',
            '-Ibuild/src',
        ]
      }
  return None
