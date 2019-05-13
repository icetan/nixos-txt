# txt

Host your own stupid simple paste bin

## Installation

In your NixOS `configuration.nix` or NixOps network.

```nix
  imports = [
    (import fetchTarball https://github.com/icetan/nixos-txt/tarball/master)
  ];

  txt = {
    enable = true;
    # Domain on which the Nginx HTTP server will be listening on
    host = "txt.example.org";
    # List of SSH public keys that will have write access via the `txt` user.
    sshKeys = [ "<SSH public key...>" ];
  };
```

## Usage

Publish a plain text:

```
echo Hello World! | ssh txt@example.org
> https://txt.example.org/oLZZOWcLwsAQ9NXWoLPk5FkPuSs
```

Publish a Markdown document as rendered HTML and brows to it:

```
xdg-open $(pandoc --from=gfm --to=html5 --self-contained < some-markdown-document.md | ssh txt@example.org).html
```

The file extension when browsing to a `txt` endpoing will determine what the
`Content-Type` response header will be set to.

## How does it work

`txt` uses a simple bash script as user shell which reads from `STDIN` and
writes to a file with a content based ID. In this way you can just pipe data to
an `ssh` client.
