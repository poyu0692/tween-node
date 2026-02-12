#!/bin/bash
# format.sh

EXCLUDE_EXTERNAL_ADDONS=${EXCLUDE_EXTERNAL_ADDONS:-1}

# 引数チェック
if [ $# -eq 0 ]; then
    echo "Usage: ./format.sh <path_to_gd_file_or_dir>"
    exit 1
fi

# 渡されたすべてのパスをループ
for path in "$@"; do
    if [ -e "$path" ]; then
        echo "Searching in: $path"
        # findでGDScriptを探してxargsで実行
        # -rオプションは入力が空の場合に実行しないようにするため
        if [ "$EXCLUDE_EXTERNAL_ADDONS" = "1" ]; then
            find "$path" -name "*.gd" -print0 \
                | while IFS= read -r -d '' file; do
                    case "$file" in
                        addons/gdUnit4/*|*/addons/gdUnit4/*|addons/GDQuest_GDScript_formatter/*|*/addons/GDQuest_GDScript_formatter/*)
                            continue
                            ;;
                        *)
                            printf '%s\0' "$file"
                            ;;
                    esac
                done \
                | xargs -0 -r ./scripts/gdscript-formatter --reorder-code
        else
            find "$path" -name "*.gd" -print0 | xargs -0 -r ./scripts/gdscript-formatter --reorder-code
        fi
    else
        echo "Warning: $path not found."
    fi
done
