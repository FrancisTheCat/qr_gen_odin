# QR Generator written Odin
This is a mostly spec-compliant, relatively fast QR-Code generator written in Odin.
## Example
```go
size := qr.bitmap_width(len(data), error_correction_level) or_else panic("Input to large")
pixels := make([]u8, size * size)
qr.generate_bitmap(data, pixels, error_correction_level)
// do something with `pixels`
```
### Attributions
All the tables in `tables.odin` come from https://www.thonky.com/qr-code-tutorial + the tutorial was also used as a reference for the implementation.
