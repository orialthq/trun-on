# Trun On portable tip (`.trunon`)

`PortableTipPackageCodec` defines the app-to-app payload shared by Android and
iOS. It is a UTF-8 JSON file with extension `.trunon` and MIME type
`application/vnd.orialthq.trunon.tip+json`. Its Apple Uniform Type Identifier is
`com.orialthq.trunon.tip`.

The file is intentionally different from the SNS preview card:

- The preview card is an image anybody can read in a chat room.
- The `.trunon` file is structured data a Trun On app can import and reuse.

## Transport behavior

| Path | Primary hand-off | Recovery path |
| --- | --- | --- |
| Android → Android | Android share sheet, Quick Share, chat or cloud file | Open the `.trunon` attachment, or use `받은 팁 파일 가져오기` |
| iOS → iOS | iOS share sheet, AirDrop, Messages, Mail or Files | Open the registered Trun On document, or import it from Files |
| Android ↔ iOS | Chat, mail or cloud as the same `.trunon` attachment | Download once and import from the Trun On add sheet |

Chat and file-provider apps can replace an unknown MIME type with
`application/octet-stream` or `application/json`. Android therefore accepts
those types only when a content URI still has the `.trunon` path, while the
manual picker accepts the provider MIME and relies on the 64 KiB limit plus the
strict v1 codec for final validation. A received package is previewed and is
not persisted until the recipient chooses `정리함에 저장`.

The 1080×1350 SNS card and the `.trunon` package remain separate actions. This
avoids platform-specific loss of text or attachments when a target app handles
mixed image-and-file shares differently.

## Version 1

```json
{
  "format": "com.orialthq.trunon.portable-tip",
  "schemaVersion": 1,
  "packageId": "tip-export-0001",
  "exportedAtEpochMs": 1785898800000,
  "tip": {
    "title": "동묘집 철판쪽꾸미",
    "summary": "종로의 철판쪽꾸미 맛집",
    "category": "restaurant_cafe",
    "subcategory": "한식",
    "details": {
      "facts": [
        { "label": "영업시간", "value": "11:00~21:00" }
      ],
      "ingredientGroups": [
        {
          "name": "양념",
          "ingredients": [
            {
              "name": "고추장",
              "amount": "1",
              "unit": "큰술",
              "preparation": null,
              "optional": false,
              "originalText": "고추장 1큰술"
            }
          ]
        }
      ],
      "steps": [
        {
          "order": 1,
          "instruction": "10분 끓인다",
          "durationSeconds": 600,
          "temperature": "100℃"
        }
      ],
      "notes": []
    },
    "place": {
      "name": "동묘집",
      "address": "서울 종로구 종로52길 43-9"
    },
    "source": {
      "label": "Instagram",
      "url": "https://example.com/post/7"
    },
    "message": "우리 주말에 같이 갈래?"
  }
}
```

`place`, `source`, and `message` are nullable, but their keys remain present in
v1. Facts, ingredients, and steps retain actionable typed values; confidence
scores and evidence ids are not exported. Card strings are derived locally
from these values. The codec rejects unknown keys and files larger than 64 KiB.

## Privacy and import invariants

- Export APIs default to no detail sections, no place, and no source. The UI
  must pass the user's explicit selections.
- There is no schema field for screenshots, attachment paths, OCR evidence,
  raw capture text, source package names, fingerprints, or original capture
  ids.
- Common tracking parameters and URL fragments are removed from source links.
- Every import requires a local id factory. The sender's `packageId` is kept
  only as `sourcePackageId` for duplicate detection and cannot become the new
  local storage id.
- Unknown schema versions must be rejected until a migration is implemented.

## Flutter entry points

- `PortableTipPackage.fromStructuredCapture(...)` maps explicitly selected
  facts, ingredient groups, and steps from a `CaptureRecord`.
- `PortableTipPackage.fromProductGroup(...)` supports the legacy product path
  and exports only explicitly selected statements.
- `PortableTipPackageCodec.encodeUtf8(...)` creates bytes for a share file.
- `PortableTipPackageCodec.importUtf8(...)` validates bytes and creates an
  `ImportedPortableTip` with a fresh local id.
