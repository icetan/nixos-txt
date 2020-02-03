{ pkgs, config, lib, ... }: with lib; let
  cfg = config.txt;
  txt-shell = (pkgs.writeScriptBin "txt-shell" ''
    #!${pkgs.dash}/bin/dash
    set -e
    export PATH="${with pkgs; makeBinPath [ coreutils mktemp openssl ]}"
    ROOT="${cfg.root}"
    mkdir -p "$ROOT"; chmod g+rx "$ROOT"
    TMP=$(mktemp txt.XXXXXXX)
    ALIAS=$(printf %s "$2" | tr /+. ---)
    ID="$(tee "$TMP" | openssl dgst -sha256 -binary | head -c12 | base64 | tr /+ _-)"
    mv "$TMP" "$ROOT/$ID"; chmod g+r "$ROOT/$ID"
    if test "$ALIAS"; then
      ln -sf -- "$ID" "$ROOT/$ALIAS-$ID"
      ln -sf -- "$ID" "$ROOT/$ALIAS"
      echo >&2 "https://${cfg.host}/$ALIAS-$ID"
      ID=$ALIAS
    fi
    echo "https://${cfg.host}/$ID"
  '').overrideAttrs (_: {
    passthru = {
      shellPath = "/bin/txt-shell";
    };
  });

  locationPathRegex = "[\\w-]{1,}";

  mkLocation = loc: ''
    location ~ "^/(?<id>${locationPathRegex})${loc.ext}$" {
      types { } default_type ${loc.type};
      try_files /$id =404;
    }
  '';

  mkLocations = attrs: let
    list = map (name: { ext = name; type = attrs."${name}"; }) (builtins.attrNames attrs);
  in pkgs.lib.concatStrings (map mkLocation (
    [{ ext = ""; type = "text/plain"; }]
    ++ (map (l: l // { ext = "\\.${l.ext}"; }) list)
  ));
in {
  options.txt = {
    enable = mkEnableOption "txt";

    user = mkOption {
      type = types.str;
      default = "txt";
      description = ''
        System user name.
      '';
    };

    sshKeys = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''
        Public SSH keys which are granted write access.
      '';
    };

    root = mkOption {
      type = types.path;
      default = "/var/lib/txt";
      description = ''
        Where to put all those txt.
      '';
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Domain name of server.
      '';
    };

    types = mkOption {
      type = with types; attrsOf str;
      default = {
        html = "text/html";
        bin = "application/octet-stream";
        png = "image/png";
        jpg = "image/jpeg";
        svg = "image/svg+xml";
        txt = "text/plain";
      };
      description = ''
        Map of extension -> MIME type.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts."${cfg.host}" = {
        forceSSL = true;
        enableACME = true;
        locations."~ \"^/${locationPathRegex}(\\.[\\w]+)?$\"" = {
          root = cfg.root;
          extraConfig = mkLocations cfg.types;
        };
      };
    };

    users.users.nginx.extraGroups = [ cfg.user ];
    users.users."${cfg.user}".openssh.authorizedKeys.keys = cfg.sshKeys;

    users.extraUsers."${cfg.user}" = {
      name = cfg.user;
      group = cfg.user;
      #uid = config.ids.uids."${cfg.user}";
      home = cfg.root;
      createHome = true;
      shell = txt-shell;
      isSystemUser = true;
    };

    users.extraGroups."${cfg.user}" = {
      name = "${cfg.user}";
    };
  };
}
