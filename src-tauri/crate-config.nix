{ ... }:
{
  "av-scenechange" = attrs: {
    preConfigure = (attrs.preConfigure or "") + ''
      # Ensure PROFILE and CARGO_ENCODED_RUSTFLAGS are set so build.rs doesn't panic
      export PROFILE=release
      export CARGO_ENCODED_RUSTFLAGS=""
    '';
  };
}