self: super:

let
  newVersion = "1.3.6";
in {
  bun = super.bun.overrideAttrs (old: rec {
    __intentionallyOverridingVersion = true;

    version = newVersion;

    # Override the actual source Bun uses
    src = super.fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v${newVersion}/bun-darwin-aarch64.zip";
      hash = "sha256-KvHshDd1mrBbOw6kIf6eIubHBctMsHUcMmmCZC2s6Po=";
    };

    # Keep passthru.sources consistent
    passthru = old.passthru // {
      sources = old.passthru.sources // {
        aarch64-darwin = src;
      };
    };
  });
}

