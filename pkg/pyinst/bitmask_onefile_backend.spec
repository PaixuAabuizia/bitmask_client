# -*- mode: python -*-

block_cipher = None

a = Analysis(['bitmask_backend.py'],
             hiddenimports=[
                'zope.interface', 'zope.proxy'],
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

exe = EXE(pyz,
          a.scripts,
          a.binaries,
          a.zipfiles,
          a.datas,
          name='bitmask_backend',
          debug=False,
          strip=False,
          upx=False,
          console=True,
          icon='../windows/bitmask.ico')
coll = COLLECT(exe,
              [],
              [],
              [],
              strip=None,
              upx=True,
              name='bitmask_onefile_backend')