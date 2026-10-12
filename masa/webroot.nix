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
  # is what an overlay's copy-up would have done. Lucee's fileCopy/fileMove
  # replace a symlink instead of writing through it, so a regular file can also
  # turn up where wwwroot already has one; the runtime copy wins then, as it
  # would have in an overlay.
  #
  # Store files all carry mtime 1, and Lucee only recompiles a class it finds
  # on disk when the source mtime changed - so after a Masa bump it would keep
  # serving the old compiled core. `link` records the Masa it linked and wipes
  # the instance's class cache when that changes.
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
            if [ -d "$dest" ] && [ ! -L "$dest" ]; then
              echo "lucee-webroot: $rel is a directory in wwwroot, keeping the runtime file as $rel.runtime" >&2
              dest="$dest.runtime"
            elif [ -e "$dest" ] || [ -L "$dest" ]; then
              if cmp -s "$target/$rel" "$dest"; then
                rm "$target/$rel"
                continue
              fi
              echo "lucee-webroot: $rel was rewritten at runtime, replacing the wwwroot copy" >&2
            elif [ -n "$masa" ] && cmp -s "$target/$rel" "$masa/$rel" 2>/dev/null; then
              # same bytes as Masa's own file: not an override, nothing to keep
              rm "$target/$rel"
              continue
            else
              echo "lucee-webroot: adopting $rel into wwwroot"
            fi
            mkdir -p "$(dirname "$dest")"
            mv -f "$target/$rel" "$dest"
          done < <(cd "$target" && find . -path ./WEB-INF -prune -o -type f -print0)
        }

        # "$dir/." so a wwwroot directory that is itself a symlink is listed too.
        names() {
          local dir
          for dir in "$@"; do
            if [ -d "$dir" ]; then
              find "$dir/." -mindepth 1 -maxdepth 1 -printf '%f\0'
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
          local wwwroot target=$2 resolved
          wwwroot=$(realpath "$1")
          [ -d "$wwwroot" ] || { echo "lucee-webroot: $1 is not a directory" >&2; exit 1; }

          # With a trailing slash a target that is still the old `ROOT -> wwwroot`
          # symlink would be treated as a directory - and emptied.
          while [ "$target" != "/" ] && [ "''${target%/}" != "$target" ]; do target=''${target%/}; done
          # Resolve the parent only: a target that *is* the old symlink gets replaced.
          resolved=$(realpath -m "$(dirname "$target")")/$(basename "$target")
          case "$resolved" in
            "$wwwroot" | "$wwwroot"/*)
              echo "lucee-webroot: refusing to build the webroot inside wwwroot ($target)" >&2
              exit 1
              ;;
          esac

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

            local marker classes
            marker="$(dirname "$target")/.lucee-webroot-masa"
            classes="$(dirname "$(dirname "$target")")/lucee-server/context/cfclasses"
            if [ "$(cat "$marker" 2>/dev/null)" != "$masa" ]; then
              if [ -d "$classes" ]; then
                rm -rf "$classes"
                echo "lucee-webroot: Masa changed, cleared the compiled class cache $classes"
              fi
              echo "$masa" > "$marker"
            fi

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
