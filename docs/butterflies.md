# Catch the butterflies

`trials/butterfly/`, task `content/tasks/catch_butterflies.tres`, on the Global motion menu.

- **Play:** butterflies circle the seated child, 0.72 m from the eyes. The net lies on the table. The child reaches and pinches it, and it stays in that hand. A hoop jump longer than 0.15 m in one tick is treated as tracking re-finding the hand, not a swing.
- **Catch them all** (`butterfly.tres`, skill `butterfly_catch`): each butterfly is judged on its own.
  - Meeting it head-on catches it. Chasing it bumps it off the rim and counts a wrong try. A still net, or a swing across its path, catches nothing.
  - The round ends when all are in the bag; then they are let go.
  - Driven axis: speed, 0.15 to 0.4 m/s. Trains vision for action, not global motion.
- **Swarm** (`butterfly_swarm.tres`, skill `butterfly_swarm`): global motion with 90 butterflies.
  - A share of the swarm (coherence, 0.9 to 0.2) flies round with the flow; the rest fly every way, and half the noise trades places each second.
  - Each swing through the swarm is judged once. Against the flow scoops 3 and wins the round. With the flow counts as a try once the net stops; turning straight into the right way forgives it as a wind-up (`catch_windup`).
  - The flow is drawn again each round.
- **Levels:** Butterfly Circle (8, one way), Both Ways (12, two circles flying opposite ways), Butterfly Swarm and Busy Swarm (3 rounds at difficulty 0 and 0.4).
- **Help:** catch-all levels slow to half speed (on a raised hand, or after 25 s). In the swarm, a raised hand makes every butterfly follow the flow.
- **Logged:** a `catch_attempt` for each judged swing, `net_taken`, the condition (spins or flow, signal count).
- **Speed:** one MultiMesh draw call, wings beat in `butterfly.gdshader`. CPU update of 90 butterflies is about 0.13 ms on a desktop.
- **Looks:** the wings are drawn by the shader as a placeholder. Planned: the CC0 "Butterfly (animated)" by CDmir (OpenGameArt).

**Not yet checked on a headset:** reaching behind the child, how the net feels, hoop size, swing thresholds, frame rate.
