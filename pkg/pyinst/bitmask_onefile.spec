# -*- mode: python -*-

block_cipher = None

a = Analysis(['bitmask.py'],
             hiddenimports=[
                'zope.interface', 'zope.proxy',
                'PySide.QtCore', 'PySide.QtGui'],
             binaries=None,
             datas=None,
             hookspath=None,
             runtime_hooks=None,
             excludes=None,
             win_no_prefer_redirects=None,
             win_private_assemblies=None,
             cipher=block_cipher)
pyz = PYZ(a.pure, a.zipped_data,
             cipher=block_cipher)

# Binary files you need to include in the form of:
# (<destination>, <source>, "<TYPE>")

# Data files you want to include, in the form of:
# (<destination>, <source>, "<TYPE>")
data = [
  ("qt.conf", "qt.conf", "DATA")
]

exe = EXE(pyz,
          a.scripts,
          a.binaries,
          a.zipfiles,
          a.datas + data,
          name='bitmask',
          debug=False,
          strip=False,
          upx=False,
          console=False,
          icon='../windows/bitmask.ico')
coll = COLLECT(exe,
              [],
              [],
              data,
              strip=None,
              upx=True,
              name='bitmask_onefile')