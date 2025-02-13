# This file has been generated by Niv.

let

  #
  # The fetchers. fetch_<type> fetches specs of type <type>.
  #

  fetch_file = pkgs: spec:
    if spec.builtin or true then
      builtins_fetchurl { inherit (spec) url sha256; }
    else
      pkgs.fetchurl { inherit (spec) url sha256; };

  fetch_tarball = pkgs: spec:
    if spec.builtin or true then
      builtins_fetchTarball { inherit (spec) url sha256; }
    else
      pkgs.fetchzip { inherit (spec) url sha256; };

  fetch_git = spec:
    builtins.fetchGit { url = spec.repo; inherit (spec) rev ref; };

  fetch_builtin-tarball = spec:
    builtins.trace
      ''
        WARNING:
          The niv type "builtin-tarball" will soon be deprecated. You should
          instead use `builtin = true`.

          $ niv modify <package> -a type=tarball -a builtin=true
      ''
      builtins_fetchTarball
      { inherit (spec) url sha256; };

  fetch_builtin-url = spec:
    builtins.trace
      ''
        WARNING:
          The niv type "builtin-url" will soon be deprecated. You should
          instead use `builtin = true`.

          $ niv modify <package> -a type=file -a builtin=true
      ''
      (builtins_fetchurl { inherit (spec) url sha256; });

  #
  # Various helpers
  #

  # The set of packages used when specs are fetched using non-builtins.
  mkPkgs = sources:
    if hasNixpkgsPath
    then
      if hasThisAsNixpkgsPath
      then import (builtins_fetchTarball { inherit (mkNixpkgs sources) url sha256; }) { }
      else import <nixpkgs> { }
    else
      import (builtins_fetchTarball { inherit (mkNixpkgs sources) url sha256; }) { };

  mkNixpkgs = sources:
    if builtins.hasAttr "nixpkgs" sources
    then sources.nixpkgs
    else
      abort
        ''
          Please specify either <nixpkgs> (through -I or NIX_PATH=nixpkgs=...) or
          add a package called "nixpkgs" to your sources.json.
        '';

  hasNixpkgsPath = (builtins.tryEval <nixpkgs>).success;
  hasThisAsNixpkgsPath =
    (builtins.tryEval <nixpkgs>).success && <nixpkgs> == ./.;

  # The actual fetching function.
  fetch = pkgs: name: spec:

    if ! builtins.hasAttr "type" spec then
      abort "ERROR: niv spec ${name} does not have a 'type' attribute"
    else if spec.type == "file" then fetch_file pkgs spec
    else if spec.type == "tarball" then fetch_tarball pkgs spec
    else if spec.type == "git" then fetch_git spec
    else if spec.type == "builtin-tarball" then fetch_builtin-tarball spec
    else if spec.type == "builtin-url" then fetch_builtin-url spec
    else
      abort "ERROR: niv spec ${name} has unknown type ${builtins.toJSON spec.type}";

  # Ports of functions for older nix versions

  # a Nix version of mapAttrs if the built-in doesn't exist
  mapAttrs = builtins.mapAttrs or (
    f: set: with builtins;
    listToAttrs (map (attr: { name = attr; value = f attr set.${attr}; }) (attrNames set))
  );

  # fetchTarball version that is compatible between all the versions of Nix
  builtins_fetchTarball = { url, sha256 }@attrs:
    let
      inherit (builtins) lessThan nixVersion fetchTarball;
    in
    if lessThan nixVersion "1.12" then
      fetchTarball { inherit url; }
    else
      fetchTarball attrs;

  # fetchurl version that is compatible between all the versions of Nix
  builtins_fetchurl = { url, sha256 }@attrs:
    let
      inherit (builtins) lessThan nixVersion fetchurl;
    in
    if lessThan nixVersion "1.12" then
      fetchurl { inherit url; }
    else
      fetchurl attrs;

  # Create the final "sources" from the config
  mkSources = config:
    mapAttrs
      (
        name: spec:
          if builtins.hasAttr "outPath" spec
          then
            abort
              "The values in sources.json should not have an 'outPath' attribute"
          else
            spec // { outPath = fetch config.pkgs name spec; }
      )
      config.sources;

  # The "config" used by the fetchers
  mkConfig =
    { sourcesFile ? ./sources.json
    , sources ? builtins.fromJSON (builtins.readFile sourcesFile)
    , pkgs ? mkPkgs sources
    }: rec {
      # The sources, i.e. the attribute set of spec name to spec
      inherit sources;

      # The "pkgs" (evaluated nixpkgs) to use for e.g. non-builtin fetchers
      inherit pkgs;
    };
in
mkSources (mkConfig { }) // { __functor = _: settings: mkSources (mkConfig settings); }
