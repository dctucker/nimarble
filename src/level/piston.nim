
#[
1   2   3   4
5   6   7   8
9   10  11  12

1 11 8  5 2 12
 3 6 9  4 7 10
]#

#[ TODO store this as 2D vector (frequency, offset)
  - frequency would be aligned for the less complex patterns with only offset differing each piston
  - offset would vary for more complex polyrhythmic patterns
]#
const piston_time_variations* = @[
  @[
    10, 30, 30, 10,
    10, 30, 30, 10,
    10, 30, 30, 10,
  ],
  @[
    35, 45, 60, 75,
    60, 75, 10, 45,
    10, 20, 35, 20,
  ],
  @[
    10, 35, 60, 85,
    35, 60, 85, 10,
    60, 85, 10, 35,
  ],
  @[
    85, 60,35, 10,
    85, 60,35, 10,
    85, 60,35, 10,
  ],
  @[
    40, 10, 40, 10,
    40, 10, 40, 10,
    40, 10, 40, 10,
  ],
]
