{ lib
, pkgs
,
}:

{
  # The production webroot: Masa first, the project's wwwroot copied over it.
  mkMasaWebroot =
    { masa
    , overlay
    , name ? "masa-webroot"
    ,
    }:
    pkgs.runCommand name { } ''
      cp -a ${masa}/. $out
      chmod -R u+w $out
      cp -a ${overlay}/. $out
    '';

  # `lucee-webroot link <wwwroot> <target>` materializes the webroot a dev instance
  # serves. Without masa that is just a symlink to wwwroot. With masa, wwwroot is
  # the upper layer of an overlay over the Masa store path, built as a tree of
  # symlinks (FUSE-free, so it works on darwin too):
  #
  #   - a directory only wwwroot has is linked whole, so edits and runtime writes
  #     (uploads, caches) land in wwwroot directly;
  #   - every other directory is real, so `core/appcfc/../../config` resolves
  #     physically inside the merged tree instead of inside the store;
  #   - files link to wwwroot when it has them, to the store otherwise.
  #
  # A file Masa creates inside a real directory (settings.ini.cfm on install,
  # plugins/mappings.cfm, ...) is moved into wwwroot by the next `link`, which
  # is what an overlay's copy-up would have done.
  #
  # `lucee-webroot prune <wwwroot> [--apply]` lists, and with --apply deletes,
  # wwwroot files that only differ from Masa's copy in line endings or
  # whitespace - for migrating projects that vendored the whole of Masa.
  mkWebrootTool =
    { masa ? null
    ,
    }:
    pkgs.writeShellApplication {
      name = "lucee-webroot";
      runtimeInputs = with pkgs; [
        coreutils
        diffutils
        findutils
        gnugrep
        gnused
      ];
      text = ''
        masa=${if masa == null then "" else masa}

        usage() {
          echo "usage: lucee-webroot link <wwwroot> <target>" >&2
          echo "       lucee-webroot prune <wwwroot> [--apply]" >&2
          exit 2
        }

        # Moves regular files out of a previously merged tree into wwwroot.
        # Symlinks are ours and get rebuilt; WEB-INF is Lucee's and regenerates.
        adopt() {
          local target=$1 wwwroot=$2 rel dest
          while IFS= read -r -d "" rel; do
            rel=''${rel#./}
            dest="$wwwroot/$rel"
            if [ -e "$dest" ] || [ -L "$dest" ]; then
              echo "lucee-webroot: $rel exists in both $target and wwwroot, keeping the runtime copy as $rel.runtime" >&2
              dest="$dest.runtime"
            else
              echo "lucee-webroot: adopting $rel into wwwroot"
            fi
            mkdir -p "$(dirname "$dest")"
            mv "$target/$rel" "$dest"
          done < <(cd "$target" && find . -path ./WEB-INF -prune -o -type f -print0)
        }

        names() {
          local dir
          for dir in "$@"; do
            if [ -d "$dir" ]; then
              find "$dir" -mindepth 1 -maxdepth 1 -printf '%f\0'
            fi
          done | sort -zu
        }

        merge() {
          local wwwroot=$1 target=$2 rel=$3 name m w t
          mkdir -p "$target$rel"
          while IFS= read -r -d "" name; do
            m="$masa$rel/$name"
            w="$wwwroot$rel/$name"
            t="$target$rel/$name"
            if [ -e "$w" ] || [ -L "$w" ]; then
              if [ -d "$w" ] && [ -d "$m" ]; then
                merge "$wwwroot" "$target" "$rel/$name"
              else
                ln -s "$w" "$t"
              fi
            elif [ -d "$m" ]; then
              merge "$wwwroot" "$target" "$rel/$name"
            else
              ln -s "$m" "$t"
            fi
          done < <(names "$masa$rel" "$wwwroot$rel")
        }

        link() {
          [ $# -eq 2 ] || usage
          local wwwroot target=$2
          wwwroot=$(realpath "$1")
          [ -d "$wwwroot" ] || { echo "lucee-webroot: $1 is not a directory" >&2; exit 1; }

          if [ -L "$target" ]; then
            rm "$target"
          elif [ -d "$target" ]; then
            adopt "$target" "$wwwroot"
            rm -rf "$target"
          fi
          mkdir -p "$(dirname "$target")"

          if [ -z "$masa" ]; then
            ln -s "$wwwroot" "$target"
          else
            merge "$wwwroot" "$target" ""
            echo "lucee-webroot: $target = $wwwroot over $masa"

            # An instance initialized before isMasa set allowLinking keeps its old
            # conf, and Tomcat then treats every symlinked file as missing.
            local context
            context="$(dirname "$(dirname "$target")")/conf/context.xml"
            if [ -f "$context" ] && ! grep -q 'allowLinking="true"' "$context"; then
              if [ "$(grep -c '<Context>' "$context")" = 1 ]; then
                sed -i 's|<Context>|<Context>\n    <Resources allowLinking="true" />|' "$context"
                echo "lucee-webroot: enabled allowLinking in $context"
              else
                echo "lucee-webroot: $context lacks <Resources allowLinking=\"true\" />, Tomcat will 404 Masa's static files" >&2
              fi
            fi
          fi
        }

        prune() {
          [ $# -ge 1 ] && [ $# -le 2 ] || usage
          local wwwroot=$1 apply=0 rel d
          [ "''${2:-}" = "--apply" ] && apply=1
          [ -n "$masa" ] || { echo "lucee-webroot: this instance has no managed Masa" >&2; exit 1; }

          while IFS= read -r -d "" rel; do
            rel=''${rel#./}
            if [ -f "$masa/$rel" ] && diff -q --strip-trailing-cr -w -B "$masa/$rel" "$wwwroot/$rel" >/dev/null; then
              echo "$rel"
              if [ $apply = 1 ]; then rm "$wwwroot/$rel"; fi
            fi
          done < <(cd "$wwwroot" && find . -type f -print0)

          if [ $apply = 1 ]; then
            # Only directories Masa provides itself: an empty project directory
            # (say, a site's cache) may be there on purpose.
            while IFS= read -r -d "" d; do
              d=''${d#./}
              if [ -d "$masa/$d" ]; then rmdir "$wwwroot/$d" 2>/dev/null || true; fi
            done < <(cd "$wwwroot" && find . -mindepth 1 -depth -type d -print0)
          else
            echo "(dry run, pass --apply to delete)" >&2
          fi
        }

        case "''${1:-}" in
          link) shift; link "$@" ;;
          prune) shift; prune "$@" ;;
          *) usage ;;
        esac
      '';
    };
}
