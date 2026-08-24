# nixpkg-overlay

保持 [oven-sh/bun](https://github.com/oven-sh/bun) 为上游最新 release 的 Nix overlay / flake。

> 当前版本：`1.4.0`（上游 `bun-v1.4.0`，2026-08-20），覆盖 `x86_64-linux` / `aarch64-linux` / `x86_64-darwin` / `aarch64-darwin`。

## 用法

### 作为 flake input（推荐）

在你的 `flake.nix` 中：

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkg-overlay = {
      url = "github:sakiko999/nixpkg-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkg-overlay, ... }:
    let system = "x86_64-linux"; in {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # 全局生效：所有 pkgs.bun 都会是 overlay 的版本
          { nixpkgs.overlays = [ nixpkg-overlay.overlays.default ]; }
          ./configuration.nix
        ];
      };
    };
}
```

之后 `home.nix` 里照常写 `bun` 即可，无需改动：

```nix
home.packages = with pkgs; [ bun ];
```

> 仅对 `bun` 生效，不影响其他包。

### 单独试用（不改系统配置）

```bash
nix run github:sakiko999/nixpkg-overlay#bun -- --version
nix shell github:sakiko999/nixpkg-overlay#bun
nix build github:sakiko999/nixpkg-overlay#bun && ./result/bin/bun --version
```

### 本仓库内验证

```bash
nix build .#bun --print-build-logs
./result/bin/bun --version
nix flake check
```

## 自动更新

- `scripts/update-bun.sh`：拉取 `oven-sh/bun` 最新 release，预取四平台 `hash`，原地更新 `pkgs/bun/package.nix`。
  ```bash
  ./scripts/update-bun.sh --check   # 仅检测
  ./scripts/update-bun.sh           # 实际更新
  nix build .#bun
  ```
- `.github/workflows/update-bun.yml`：每天 02:17 UTC 自动运行，检测到新版则构建验证并提 PR（`update/bun-<version>`）。

## 结构

```
flake.nix                   # overlays.default / packages.bun
overlay.nix                 # final: prev: { bun = ... }
pkgs/bun/package.nix        # 复刻 nixpkgs 的 bun 打包逻辑，version/hash 保持最新
scripts/update-bun.sh       # 本地一键更新
.github/workflows/update-bun.yml
```

## 说明

- 打包逻辑与上游 nixpkgs `pkgs/by-name/bu/bun/package.nix` 一致（`fetchurl` 二进制 + `autoPatchelfHook` + shell completions），仅 `version` / `hash` 滚动。
- `x86_64-linux` 使用 `bun-linux-x64-baseline.zip` 以兼容更多 CPU（与 nixpkgs 一致）。
