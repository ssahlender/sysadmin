# Windows on Mac

> M4 = ARM only — no Boot Camp. All options run **Windows ARM**, not x86. Most modern software works fine via Microsoft's x86 translation layer.

| Option | Cost | Best for | Link |
|--------|------|----------|------|
| [Parallels Desktop](https://www.parallels.com) | ~$100/yr | Windows daily use, seamless integration | https://www.parallels.com |
| [UTM](https://mac.getutm.app) | Free | Occasional use, more manual setup | https://mac.getutm.app |
| [VMware Fusion](https://www.vmware.com/products/fusion.html) | Free (personal) | Middle ground, no subscription | https://www.vmware.com/products/fusion.html |

```bash
brew install --cask utm             # free
brew install --cask parallels       # paid, best integration
brew install --cask vmware-fusion   # free personal tier
```

> Start with UTM (free). Upgrade to Parallels only if you need Windows daily.
