# Notes on evolutionary version
- handle collision between particles
- handle destruction of particles

## version 1 - ecosystem of particles
- particles have energy. When they cross some energy threshold they multiply and divide the energy
- divison incurs in random mutations to the genes
- energy decreases over time
- particles can be of a single species. Or a set of species (behaviors) might make for more interesting dynamics
- every particle has a weight array for other species. This is the genome that can be randomly mutated
- problem with this approach is that every species has a single optimal strategy, not much room for variation
- distinguish between active energy (aliveness) and passive energy/mass (can be converted to other forms on death)
- particles grow in size based on mass?
particles types:
- C carnivore: can eat other species that are not P on collision
- P plants: dont move, grow in energy following something like a normal
- H herbivores: can only eat P. Leave behind trails of F
- D defenders: can eat F. Can destroy C on collision, but don't gain energy from it. Should form symbiotic relation with H
- F : only acts as food for other species?
- B bodies: when other particles die, they turn into bodies B. B turns into P after some time
- S scavengers: Scavengers can eat B

## version 2 - more flexibilty
- make all the behaviors of species in v1 customizable. All above behaviors can be described this way. Ie:
  - on death -> create species X
  - on collision -> eat species X, die to species Y
  - on split -> leave behind species X
  - timed/every X seconds -> produce species X
  - speed
- Might make for more customization and interesting interaction
- can maybe introduce rare species mutations where the species can get a change (creates a new species).
  - complicated to create new specis since others depend on a fixed number (weights), maybe just stay in the same species and can have individual mutations over time.
  - or have fixed global species and their mutations happen slowly to all members (less realistic). Can reward certain mutations so that the species evolves faster overall
- sexual/asexual reproduction, laying eggs?

## version 3 -
- cell DNA is formed of behaviors (genes) + how they react to other behaviors. The attraction is a function of the other cell behavior (+ my behavior? maybe superflous)
- cell color is a hash of their DNA so similarly colored are a similar "species"

## version 3 - trying to model cells
what level to simulate? cells forming an organism, or proteins/molecules forming a cell?