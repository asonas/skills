"""Render verified extracts as report.md, preserving the Wiki links section."""

import argparse
import json
import os
import tempfile
from pathlib import Path
from urllib.parse import quote

from report import verify

BEGIN = "<!-- digger:related:start -->"
END = "<!-- digger:related:end -->"


def render(topic):
    data = json.loads((topic / "extracts.json").read_text(encoding="utf-8"))
    groups = data["claims"] + data.get("disagreements", [])
    for group in groups:
        for item in group.get("quotes", []):
            if not verify(topic / "sources", item)[0]:
                raise ValueError(f"原文に見つからない: {item['file']}:{item['line']}")
    out = topic / "report.md"
    related = "\n## 関連Wiki\n\n"
    if out.exists():
        old = out.read_text(encoding="utf-8")
        if BEGIN in old and END in old:
            related = old.split(BEGIN, 1)[1].split(END, 1)[0]
    lines = ["---", "generated_by: digger", "---", "", f"# {data['title']}", "",
             f"問い：{data['question']}", "", f"終了理由：{data['stopped']}", "",
             "[探索地図](map.md) · [探索ログ](log.md)", ""]
    for group in groups:
        lines += [f"## {group.get('claim', group.get('topic', '食い違い'))}", ""]
        if group.get("status"):
            lines += [f"状態：{group['status']}", ""]
        if group.get("note"):
            lines += [f"注記：{group['note']}", ""]
        for item in group.get("quotes", []):
            if item.get("who"):
                lines += [f"発言者：{item['who']}", ""]
            lines += ["> " + line for line in item["text"].split("\n")]
            lines += [""]
            location = f"{item['line']}–{item.get('end') or item['line']}行"
            path = quote("sources/" + item["file"], safe="/")
            lines += [f"出典：[本文]({path})（{location}）", ""]
            for key, label in (("ja", "訳"), ("mark", "資料種別"), ("context_note", "文脈")):
                if item.get(key):
                    lines += [f"{label}：{item[key]}", ""]
            # Metadata is maintained by the acquisition workflow, outside raw text.
            metadata = Path(item["file"]).with_name(Path(item["file"]).stem + "-metadata.md")
            if (topic / "sources" / metadata).is_file():
                lines += [f"[原典URL・取得範囲](<{quote('sources/' + str(metadata), safe='/')}>)", ""]
    lines += ["## 未解決・未取得", ""]
    lines += [f"- {item}" for item in data.get("unreached", [])]
    lines += ["", BEGIN + related + END, ""]
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=topic,
                                     prefix=".report-", delete=False) as handle:
        temporary = Path(handle.name)
        try:
            handle.write("\n".join(lines))
            handle.close()
            os.replace(temporary, out)
        finally:
            temporary.unlink(missing_ok=True)
    return out


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("topic", type=Path)
    args = parser.parse_args()
    try:
        print(render(args.topic.expanduser()))
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"report.mdを更新できません: {error}\n")
