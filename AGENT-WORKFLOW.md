# Faster agent runs (measured on one night of district builds)

Each agent step costs about 10 to 15 seconds, so total time follows the number of tool calls an agent makes.

1. **One agent per item group.** A 16-item diagnosis took 333 s in one agent (26 tool calls). Split it, and each group takes about a minute in parallel. Give one connector design per agent, not two.
2. **Cache the road graph.** `loop_gen.ps1 -UseCache` keeps the roads around a district for 6 hours, so a second and third corner set on the same district skip the road read.
3. **Generate the packet.** `make_packet.ps1` writes the proposal packet (loop size, prefabs, one-way pieces, shelter-clash list, cost) from the loop file, so an agent only writes the reason and the decision.
4. **Use the lighter model for scripted work.** Designs and checks are mostly commands, not judgement. Keep the stronger model for the Mayor decision.
5. **Run `check_stops.ps1` before placing shelters,** so a clash is moved on paper and not discovered in the game.
6. **Batch the approval round.** Collect all packets, then take them to the Mayor once.

7. **Find the corners by script.** `find_cycle.ps1 -Cx <x> -Cz <z> -R <r>` looks for a closed two-way road cycle near a point and prints the `loop_gen` command with corner junction ids. Hand-picked corner rectangles failed with NO PATH three times in a row on one test; the script found a cycle in under a second, or says plainly that none exists. The full chain (find_cycle, loop_gen, make_packet) ran in 12 s in the test.

Note: PowerShell variable names are not case-sensitive (` $E ` and ` $e `, ` $cx ` and ` $Cx ` are the same variable). Two bugs in find_cycle came from this.
