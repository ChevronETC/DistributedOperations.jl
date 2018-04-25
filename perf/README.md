I ran with `2`, `4`, `8`, `16`, `32` and `64` nodes with the following results measured in seconds for `1GB` and `10GB` arrays,

# 1GB

|Nodes|bcast |reduce|reduce normalized cost|
|-----|------|------|----------------------|
|2    | 2.7  | 2.4  | 1                    |
|4    | 4.9  | 4.7  | 1.96                 |
|8    | 7.4  | 7.2  | 3.00                 |
|16   | 10.0 | 9.6  | 4.00                 |
|32   | 12.8 | 11.8 | 4.92                 |
|64   | 16.2 | 15.0 | 6.25                 |

# 10GB

|Nodes|bcast  |reduce |reduce normalized cost|
|-----|-------|-------|----------------------|
|2    | 22.4  | 21.4  | 1                    |
|4    | 43.3  | 45.9  | 2.15                 |
|8    | 67.3  | 71.5  | 3.34                 |
|16   | 92.9  | 96.7  | 4.52                 |
|32   | 116.6 | 120.7 | 5.64                 |
|64   | 139.5 | 147.9 | 6.91                 |

This implies that for `64` nodes, `100GB` of data would take `1200` seconds for a reduction which is about `20` minutes, 50GB of data would be `10` minutes, and so on and so forth.  We can also extrapolate the timing for `10GB` on `400` nodes which, in theory, should be about `3` minutes.
