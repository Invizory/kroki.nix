{ config, lib, ... }:
{
  options.services.kroki =
    let
      mkFeatureOption =
        { name, image }:
        let
          fullName = "Kroki ${name}";
        in
        {
          enable = lib.mkEnableOption "${fullName} support";
          version = mkVersionOption { inherit fullName image; };
          inherit extraEnvironment;
        };
      mkVersionOption =
        {
          fullName,
          image,
        }:
        lib.mkOption {
          type = lib.types.str;
          description = ''
            ${fullName} version to use.

            See [the releases list](https://github.com/yuzutech/kroki/releases) and [`${image}` image tags](https://hub.docker.com/r/yuzutech/${image}/tags).
          '';
          example = "0.27.0";
        }
        // (
          if image == "kroki" then
            {
              default = "latest";
            }
          else
            {
              default = config.services.kroki.version;
              defaultText = lib.literalExpression "config.services.kroki.version";
            }
        );
      extraEnvironment = lib.mkOption {
        type = with lib.types; attrsOf str;
        description = ''
          Additional environment variables to pass to the container.

          See [Kroki configuration manual](https://docs.kroki.io/kroki/setup/configuration/) for details.
        '';
        default = { };
      };
    in
    {
      enable = lib.mkEnableOption "Kroki";
      version = mkVersionOption {
        fullName = "Kroki";
        image = "kroki";
      };
      listen = {
        address = lib.mkOption {
          type = with lib.types; nullOr str;
          description = ''
            Address of the interface for Kroki gateway server to listen on.

            Use `null` to listen on all interfaces.
          '';
          default = null;
          example = "localhost";
        };
        port = lib.mkOption {
          type = with lib.types; port;
          description = ''
            TCP port for Kroki gateway server to listen on.
          '';
          default = 8000;
        };
      };
      safeMode = lib.mkOption {
        type =
          with lib.types;
          enum [
            "unsafe"
            "safe"
            "secure"
          ];
        description = ''
          Kroki provides security levels that restrict access to files on the file system and on the network.
          Each level includes the restrictions enabled in the prior security level:

          * `unsafe`: disables any security features.
          * `safe`: assume the diagram libraries secure mode request sanitization is sufficient.
          * `secure`: prevents attempts to read files from the file system or from the network.

          See [safe mode description](https://docs.kroki.io/kroki/setup/configuration/#_safe_mode).
        '';
        default = "secure";
      };
      plantuml = {
        allowInclude = lib.mkOption {
          type = with lib.types; nullOr bool;
          description = ''
            Determines if PlantUML will fetch `!include` directives that reference external URLs.
            For example, PlantUML allows the `!import` directive to pull fragments from the filesystem, a remote URL, or the standard library.
          '';
          default = null;
        };
        includePath = lib.mkOption {
          type = with lib.types; nullOr str;
          description = ''
            The include path to set for PlantUML.
          '';
          default = null;
        };
        includeWhitelist = lib.mkOption {
          type = with lib.types; listOf str;
          description = ''
            Java regular expressions for valid includes.
          '';
          default = [ ];
          example = [ "^https://raw.githubusercontent.com/plantuml/plantuml/" ];
        };
      };
      features = {
        mermaid = mkFeatureOption {
          name = "Mermaid";
          image = "kroki-mermaid";
        };
        bpmn = mkFeatureOption {
          name = "BPMN";
          image = "kroki-bpmn";
        };
        excalidraw = mkFeatureOption {
          name = "Excalidraw";
          image = "kroki-excalidraw";
        };
        diagramsnet = mkFeatureOption {
          name = "diagrams.net";
          image = "kroki-diagramsnet";
        };
      };
      inherit extraEnvironment;
    };

  config.virtualisation.quadlet =
    let
      cfg = config.services.kroki;
    in
    lib.mkIf cfg.enable (
      let
        inherit (config.virtualisation.quadlet) networks pods;
        imageBase = "docker.io/yuzutech";
        features = lib.remove null (
          lib.mapAttrsToList (name: { enable, ... }: if enable then name else null) cfg.features
        );
        publishPorts = [
          "${
            let
              inherit (cfg.listen) address;
            in
            if address != null then "${address}:" else ""
          }${toString cfg.listen.port}:8000"
        ];
        environments = lib.mkMerge [
          cfg.extraEnvironment
          {
            KROKI_SAFE_MODE = cfg.safeMode;
          }
          (lib.mergeAttrsList (
            map (feature: {
              "KROKI_${lib.toUpper feature}_HOST" = "kroki-${feature}";
            }) features
          ))
          (lib.mkIf (cfg.plantuml.allowInclude != null) {
            KROKI_PLANTUML_ALLOW_INCLUDE = toString cfg.plantuml.allowInclude;
          })
          (lib.mkIf (cfg.plantuml.includePath != null) {
            KROKI_PLANTUML_INCLUDE_PATH = cfg.plantuml.includePath;
          })
          (lib.mergeAttrsList (
            lib.imap0 (i: pattern: {
              "KROKI_PLANTUML_INCLUDE_WHITELIST_${toString i}" = pattern;
            }) cfg.plantuml.includeWhitelist
          ))
        ];
      in
      {
        containers = {
          kroki-server.containerConfig = {
            pod = pods.kroki.ref;
            image = "${imageBase}/kroki:${cfg.version}";
            networks = [ networks.kroki.ref ];
            inherit publishPorts environments;
          };
        }
        // lib.mergeAttrsList (
          map (feature: {
            "kroki-${feature}".containerConfig = {
              pod = pods.kroki.ref;
              image = "${imageBase}/kroki-${feature}:${cfg.features.${feature}.version}";
              networks = [ networks.kroki.ref ];
              environments = cfg.features.${feature}.extraEnvironment;
            };
          }) features
        );
        networks.kroki = { };
        pods.kroki = { };
      }
    );
}
