# Contributing to DragonForge

Thanks for wanting to contribute. Here's how.

## Reporting Issues

- Include your distro, kernel version, GPU model, and IOMMU group layout
- Run `./dragonforge detect` and paste the output
- Include relevant logs: `journalctl -t DragonForge --no-pager`

## Submitting Changes

1. Fork the repo
2. Create a branch: `git checkout -b fix/your-fix`
3. Make your changes
4. Test on your hardware
5. Submit a PR with a clear description of what changed and why

## Adding Hardware Compatibility

If you've tested DragonForge on your hardware, add an entry to the "Known Working Laptops" table in `docs/LAPTOP_GUIDE.md` or "Tested On" in `README.md`.

## Code Style

- Shell scripts: bash, `set -euo pipefail`, functions for reusable logic
- Use the existing logging functions (`log`, `warn`, `die`)
- Keep it simple — this is a tool for humans debugging hardware problems

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
