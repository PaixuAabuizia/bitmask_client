# -*- mode: python -*-

block_cipher = None

a = Analysis(['bitmask_frontend.py'],
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

data = [
  ("qt.conf", "qt.conf", "DATA")
]

exe = EXE(pyz,
          a.scripts,
          a.binaries,
          a.zipfiles,
          a.datas + data,
          name='bitmask_frontend',
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
              name='bitmask_onefile_frontend')