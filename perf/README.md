I ran with `2`, `4`, `8`, `16`, `32` and `64` nodes with the following results measured in seconds for `1GB` and `10GB` arrays,

# 1GB

## NADC

|Nodes|bcast |reduce|reduce normalized cost|
|-----|------|------|----------------------|
|2    | 2.7  | 2.4  | 1                    |
|4    | 4.9  | 4.7  | 1.96                 |
|8    | 7.4  | 7.2  | 3.00                 |
|16   | 10.0 | 9.6  | 4.00                 |
|32   | 12.8 | 11.8 | 4.92                 |
|64   | 16.2 | 15.0 | 6.25                 |

## NADC (Intel MPI, untuned)
[Alex: the scling of reduce is WAY too good]

|Nodes|bcast |reduce|reduce normalized cost|
|-----|------|------|----------------------|
|2    | 2.0  | 1.1  | 1                    |
|4    | 2.9  | 1.4  | 1.23                 |
|8    | 3.6  | 2.0  | 1.70                 |
|16   | 3.7  | 2.1  | 1.79                 |
|32   | 6.1  | 4.4  | 3.74                 |
|64   | 7.6  | 6.0  | 5.18                 |

## GCE, n1-standard-16

|Nodes|bcast |reduce|reduce normalized cost|
|-----|------|------|----------------------|
|2    | 1.19 | 1.38 | 1                    |
|4    | 2.13 | 2.5  | 1.81                 |
|8    | 3.15 | 3.97 | 2.88                 |
|16   | 4.05 | 5.48 | 3.97                 |
|32   | 5.48 | 7.02 | 5.09                 |
|64   | 7.62 | 8.98 | 6.51                 |

# 10GB

## NADC

|Nodes|bcast  |reduce |reduce normalized cost|
|-----|-------|-------|----------------------|
|2    | 22.4  | 21.4  | 1                    |
|4    | 43.3  | 45.9  | 2.15                 |
|8    | 67.3  | 71.5  | 3.34                 |
|16   | 92.9  | 96.7  | 4.52                 |
|32   | 116.6 | 120.7 | 5.64                 |
|64   | 139.5 | 147.9 | 6.91                 |

This implies that for `64` nodes, `100GB` of data would take `1200` seconds for a reduction which is about `20` minutes, 50GB of data would be `10` minutes, and so on and so forth.  We can also extrapolate the timing for `10GB` on `400` nodes which, in theory, should be about `3` minutes.
