# set(CMAKE_EXPORT_COMPILE_COMMANDS "ON")
# vim: sw=2 sts=2

import os.path
thisDir = os.path.abspath( os.path.dirname( __file__ ) )

def Settings( **kwargs ):
  language = kwargs[ 'language' ]
  if language == 'cfamily':
    cmake_commands = os.path.join( thisDir, 'build', 'compile_commands.json')
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

