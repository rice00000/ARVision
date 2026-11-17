# Catch the butterflies

`trials/butterfly/`, task `content/tasks/catch_butterflies.tres`, on the Global motion menu.

- **Play:** butterflies circle the seated child, 0.72 m from the eyes. The net lies on the table. The child reaches and pinches it, and it stays in that hand. The handle runs along the hand's aim ray (the cursor's ray on the PC), so the hoop is where the child aims. A hoop jump longer than 0.15 m in one tick is treated as tracking re-finding the hand, not a swing.
- **Net:** the moving hoop checks every butterfly along its path. Depth gets extra reach (0.25 m, compared with 0.15 m across and up or down). Each catch flies through the hoop. The bag holds six and lets the oldest fly out as new ones arrive.
- **Catch them all** (`butterfly.tres`, skill `butterfly_catch`): meet each butterfly head-on. Chasing it counts as a wrong try. Catch every butterfly to finish the round. Speed ranges from 0.15 to 0.4 m/s.
- **Swarm** (`butterfly_swarm.tres`, skill `butterfly_swarm`): global motion with 90 butterflies.
  - A share of the swarm (coherence, 0.9 to 0.2) flies round with the flow; the rest fly every way, and half the noise trades places each second.
  - A swing against the flow wins when it ends with at least one catch. It scoops each butterfly it meets. With the flow counts as a try once the net stops. Turning straight into the right way forgives the wind-up (`catch_windup`).
  - The flow is drawn again as soon as the round is scored. The net can keep catching through the closing animation.
- **Levels:** Butterfly Circle (8, one way), Both Ways (12, two circles flying opposite ways), Butterfly Swarm and Busy Swarm (3 rounds at difficulty 0 and 0.4).
- **Help:** catch-all levels slow to half speed (on a raised hand, or after 25 s). In the swarm, a raised hand makes every butterfly follow the flow.
- **Logged:** `catch_attempt` per catch or wrong bump in catch-all, per scored swing in the swarm. Also `net_taken` and the condition (spins or flow, signal count).
- **Rendering:** one MultiMesh draw call, wings beat in `butterfly.gdshader`.
- **Looks:** CC0 "Butterfly (animated)" by Čestmír Dammer (CDmir, OpenGameArt) in `content/butterflies/`. Its mesh is baked flat for the MultiMesh and the shader beats the wings (the model's own animation is not used). The other species are its monarch skin with the orange turned blue, yellow, cream or pink.

**Not yet checked on a headset:** reaching behind the child, how the net feels, hoop size, swing thresholds, frame rate.
