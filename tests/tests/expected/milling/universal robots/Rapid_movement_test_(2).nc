%
(MYCOMMENT)
(G-code output for Universal Robots' Remote TCP & Toolpath URCap)
(Compatible with Polyscope 5.11.4 and above)
N1 G90
N2 G21
(Spindle Speed      = 6000 RPM)
(Tool               = 7)
(Toolpath name      = Rapid_movement_test_2)
(Head angle         = 30 deg)
N3 G00 X-43.536 Y18.536 Z9.9
(First Toolpath Point)
(Cutting Move Starts)
N4 X-43.536 Y18.536 Z9.9
N5 X-43.536 Y18.536 Z-0.1
N6 G01 X-43.536 Y18.536 Z-0.2 F333.332
N7 G00 X-43.536 Y18.536 Z-0.1 F1000
N8 X0. Y-18.536 Z-0.1
N9 X0. Y-18.536 Z-0.1
N10 G01 X0. Y-18.536 Z-0.2 F333.332
N11 G00 X0. Y-18.536 Z-0.1 F1000
(Rapid Move Starts)
N12 X0. Y-18.536 Z9.9
N13 M30
%
