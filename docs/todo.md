# bugs
- resizing window -> spatial index
- default window doesn't have correct tile sizing (spatial index)
- some asserts: sim.odin(190:2) runtime assertion: pos.y < size.y

# optimizations
- symmetric pass
- break operations (separate integration etc)
- multithreading on desktop

# features
- repeating scene
- genetic evolution of weights, collisions to make particles fight etc. should be separate branch
- better ui