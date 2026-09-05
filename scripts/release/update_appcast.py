#!/usr/bin/env python3

import argparse
from pathlib import Path
from xml.dom import Node, minidom


def element_text(element: minidom.Element) -> str:
    return "".join(
        child.data
        for child in element.childNodes
        if child.nodeType in (Node.TEXT_NODE, Node.CDATA_SECTION_NODE)
    )


def append_text_element(
    document: minidom.Document,
    parent: minidom.Element,
    name: str,
    value: str,
) -> minidom.Element:
    element = document.createElement(name)
    element.appendChild(document.createTextNode(value))
    parent.appendChild(element)
    return element


def append_cdata(document: minidom.Document, parent: minidom.Element, value: str) -> None:
    remaining = value
    while "]]>" in remaining:
        before, remaining = remaining.split("]]>", 1)
        parent.appendChild(document.createCDATASection(f"{before}]]"))
        remaining = f">{remaining}"
    parent.appendChild(document.createCDATASection(remaining))


def remove_whitespace_nodes(node: Node) -> None:
    for child in list(node.childNodes):
        if child.nodeType == Node.TEXT_NODE and not child.data.strip():
            node.removeChild(child)
            child.unlink()
        elif child.hasChildNodes():
            remove_whitespace_nodes(child)


def update_appcast(
    appcast_path: Path,
    *,
    version: str,
    sparkle_version: str,
    tag: str,
    dmg_url: str,
    file_size: str,
    signature: str,
    release_date: str,
    repository: str,
    release_notes_html: str,
    max_items: int,
) -> None:
    document = minidom.parse(str(appcast_path))
    channels = document.getElementsByTagName("channel")
    if len(channels) != 1:
        raise ValueError("appcast must contain exactly one channel")
    channel = channels[0]

    for item in list(channel.getElementsByTagName("item")):
        versions = item.getElementsByTagName("sparkle:shortVersionString")
        if versions and element_text(versions[0]) == version:
            channel.removeChild(item)
            item.unlink()

    item = document.createElement("item")
    append_text_element(document, item, "title", f"Version {version}")
    append_text_element(
        document,
        item,
        "link",
        f"https://github.com/{repository}/releases/tag/{tag}",
    )
    append_text_element(document, item, "sparkle:version", sparkle_version)
    append_text_element(document, item, "sparkle:shortVersionString", version)

    description = document.createElement("description")
    notes = f"<h2>Image Studio {version}</h2>\n{release_notes_html.strip()}"
    append_cdata(document, description, notes)
    item.appendChild(description)
    append_text_element(document, item, "pubDate", release_date)

    enclosure = document.createElement("enclosure")
    enclosure.setAttribute("url", dmg_url)
    enclosure.setAttribute("sparkle:version", sparkle_version)
    enclosure.setAttribute("sparkle:shortVersionString", version)
    enclosure.setAttribute("sparkle:edSignature", signature)
    enclosure.setAttribute("length", file_size)
    enclosure.setAttribute("type", "application/octet-stream")
    item.appendChild(enclosure)

    marker = next(
        (
            child
            for child in channel.childNodes
            if child.nodeType == Node.COMMENT_NODE
            and "Latest release will be added here" in child.data
        ),
        None,
    )
    channel.insertBefore(item, marker.nextSibling if marker else channel.firstChild)

    for stale_item in list(channel.getElementsByTagName("item"))[max_items:]:
        channel.removeChild(stale_item)
        stale_item.unlink()

    remove_whitespace_nodes(document)
    appcast_path.write_bytes(document.toprettyxml(indent="  ", encoding="utf-8"))


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Add one signed release to a Sparkle appcast.")
    parser.add_argument("--appcast", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--sparkle-version", required=True)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--dmg-url", required=True)
    parser.add_argument("--file-size", required=True)
    parser.add_argument("--signature", required=True)
    parser.add_argument("--release-date", required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--release-notes-file", type=Path, required=True)
    parser.add_argument("--max-items", type=int, default=3)
    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    update_appcast(
        arguments.appcast,
        version=arguments.version,
        sparkle_version=arguments.sparkle_version,
        tag=arguments.tag,
        dmg_url=arguments.dmg_url,
        file_size=arguments.file_size,
        signature=arguments.signature,
        release_date=arguments.release_date,
        repository=arguments.repository,
        release_notes_html=arguments.release_notes_file.read_text(),
        max_items=arguments.max_items,
    )


if __name__ == "__main__":
    main()
