{ pkgs, config, lib, ... }: with lib; let
  cfg = config.txt;
  txt-shell = (pkgs.writeScriptBin "txt-shell" ''
    #!${pkgs.dash}/bin/dash
    set -e
    export PATH="${with pkgs; makeBinPath [ coreutils mktemp openssl ]}"
    ROOT="${cfg.root}"
    mkdir -p "$ROOT"; chmod g+rx "$ROOT"
    TMP="$(mktemp txt.XXXXXXX)"
    ID="$(tee "$TMP" | openssl dgst -sha1 -binary | base64 | head -c 27 | tr /+ _-)"
    mv "$TMP" "$ROOT/$ID"; chmod g+r "$ROOT/$ID"
    echo "https://${cfg.host}/$ID"
  '').overrideAttrs (_: {
    passthru = {
      shellPath = "/bin/txt-shell";
    };
  });
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
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts."${cfg.host}" = {
        forceSSL = true;
        enableACME = true;
        #locations."/" = {
        #  root = cfg.root;
        #};
        locations."~ \"^/[\\w-]{27}(\\.[\\w]+)?$\"" = {
          root = cfg.root;
          extraConfig = ''
            location ~ "^/(?<id>[\\w-]{27})$" {
              types { } default_type text/plain;
              try_files /$id =404;
            }
            location ~ "^/(?<id>[\\w-]{27})\\.html$" {
              types { } default_type text/html;
              try_files /$id =404;
            }
            location ~ "^/(?<id>[\\w-]{27})\\.bin$" {
              types { } default_type application/octet-stream;
              try_files /$id =404;
            }
            location ~ "^/(?<id>[\\w-]{27})\\.png$" {
              types { } default_type image/png;
              try_files /$id =404;
            }
            location ~ "^/(?<id>[\\w-]{27})\\.jpg$" {
              types { } default_type image/jpeg;
              try_files /$id =404;
            }
          '';
        };
      };
    };

    users.users.nginx.extraGroups = [ cfg.user ];
    users.users."${cfg.user}".openssh.authorizedKeys.keys = cfg.sshKeys;

    users.extraUsers = [
      {
        name = cfg.user;
        group = cfg.user;
        #uid = config.ids.uids."${cfg.user}";
        home = cfg.root;
        createHome = true;
        shell = txt-shell;
        isSystemUser = true;
      }
    ];

    users.extraGroups = [
      { name = "${cfg.user}"; }
    ];
  };
}
