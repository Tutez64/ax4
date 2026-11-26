Working changelog for the next release. Update it as work lands.
At tag time, copy these sections into the GitHub release notes.


## Fixed

- Outside flash, a Date's time is read in whole milliseconds, as Flash gives it: `getTime()`, `time` and `valueOf()` round the seconds a native Date holds. Code that truncated the difference between two times lost half a millisecond each time, so a game comparing its frame clock with `new Date()` saw its clock run 10% fast above 180 frames a second.

## Performance

- On C++, reading a field of an anonymous object through `ASAny` goes straight to the field. A field that was null or missing was looked for among the reflected fields of a class, the dynamic properties kept aside and the named children of a display object, none of which such an object has.
- On C++, `toNumber` on an untyped value returns a Float or an Int as soon as its type tag says so, without the five type tests that came first.

  With both, in a game whose Starling Animate animations read their frame data from such objects, advancing the animations took 0.16 ms a frame and takes 0.14 ms.
