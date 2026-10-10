{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  unzip,
  installShellFiles,
  makeWrapper,
  openssl,
  writeShellScript,
  curl,
  jq,
  common-updater-scripts,
  cctools,
  darwin,
  rcodesign,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  version = "1.4.3";
  pname = "bun";

  src =
    finalAttrs.passthru.sources.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  # 上游 zip 解压后均含一层目录（与 nixpkgs 历史行为一致，但 1.4.0+ 各平台均带目录）
  sourceRoot =
    {
      aarch64-darwin = "bun-darwin-aarch64";
      aarch64-linux = "bun-linux-aarch64";
      x86_64-darwin = "bun-darwin-x64";
      x86_64-linux = "bun-linux-x64-baseline";
    }
    .${stdenvNoCC.hostPlatform.system} or null;

  strictDeps = true;
  nativeBuildInputs = [
    unzip
    installShellFiles
    makeWrapper
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = [ openssl ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm 755 ./bun $out/bin/bun
    ln -s $out/bin/bun $out/bin/bunx
    runHook postInstall
  '';

  postPhases = [ "postPatchelf" ];
  postPatchelf =
    lib.optionalString stdenvNoCC.hostPlatform.isDarwin ''
      '${lib.getExe' cctools "${cctools.targetPrefix}install_name_tool"}' $out/bin/bun \
        -change /usr/lib/libicucore.A.dylib '${lib.getLib darwin.ICU}/lib/libicucore.A.dylib'
      '${lib.getExe rcodesign}' sign --code-signature-flags linker-signed $out/bin/bun
    ''
    + lib.optionalString (stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform) ''
      installShellCompletion --cmd bun \
        --bash <(SHELL="bash" $out/bin/bun completions) \
        --zsh <(SHELL="zsh" $out/bin/bun completions) \
        --fish <(SHELL="fish" $out/bin/bun completions)
    '';

  passthru = {
    sources = {
      "aarch64-darwin" = fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-darwin-aarch64.zip";
        hash = "sha256-gK/UwGm0am+o8+xSC+vHUKeEPkqNW5WD0prUNsAKNAM=";
      };
      "aarch64-linux" = fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-aarch64.zip";
        hash = "sha256-76mBPaXtckI7+Ef5FujSxHwNd2rdlyNUAmp14Q2pqiE=";
      };
      "x86_64-darwin" = fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-darwin-x64.zip";
        hash = "sha256-YmYOZDjrhyJ4h3rMp34RUtXQMTJN82jUqBtCghFInS0=";
      };
      "x86_64-linux" = fetchurl {
        url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-x64-baseline.zip";
        hash = "sha256-H8LtrIQxApCeOhvh2NmALMYHHPB05n6IIx9P/g+LOXs=";
      };
    };
    updateScript = writeShellScript "update-bun" ''
      set -o errexit
      export PATH="${
        lib.makeBinPath [
          curl
          jq
          common-updater-scripts
        ]
      }"
      NEW_VERSION=$(curl --silent https://api.github.com/repos/oven-sh/bun/releases/latest | jq '.tag_name | ltrimstr("bun-v")' --raw-output)
      if [[ "${finalAttrs.version}" = "$NEW_VERSION" ]]; then
          echo "The new version same as the old version."
          exit 0
      fi
      for platform in ${lib.escapeShellArgs finalAttrs.meta.platforms}; do
        update-source-version "bun" "$NEW_VERSION" --ignore-same-version --source-key="sources.$platform"
      done
    '';
  };
  meta = {
    homepage = "https://bun.sh";
    changelog = "https://bun.sh/blog/bun-v${finalAttrs.version}";
    description = "Incredibly fast JavaScript runtime, bundler, transpiler and package manager – all in one";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    longDescription = ''
      All in one fast & easy-to-use tool. Instead of 1,000 node_modules for development, you only need bun.
    '';
    license = with lib.licenses; [
      mit
      lgpl21Only
    ];
    mainProgram = "bun";
    maintainers = with lib.maintainers; [
      DAlperin
      jk
      thilobillerbeck
      cdmistman
      diogomdp
    ];
    platforms = builtins.attrNames finalAttrs.passthru.sources;
    broken = stdenvNoCC.hostPlatform.isMusl;
  };
})
