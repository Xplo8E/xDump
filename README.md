# xDump
yet another FairPlay DRM breaker using `mremap_encrypted` for ios apps

## ⚠️ WARNING ⚠️
**This project is in early development and NOT ready for use. Proceed with caution.**

## Analysis

### Issues
- `mremap_encrypted` returns `EPERM` (possibly due to codesigning)
- Unable to decrypt encrypted binaries
- Application icon not displaying

### Wins
currently this one detects ios app encryption, by checking `LC_ENCRYPTION_INFO_64 -> cryptid`,whether it is encrypted or decrypted binary ( decrypted = `cryptid == 0` ), it copies the output to `/private/var/mobile/Documents/Decrypt-output`.

