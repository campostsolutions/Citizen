%
(MYCOMMENT)
(G-code output for Universal Robots' Remote TCP & Toolpath URCap)
(Compatible with Polyscope 5.11.4 and above)
N1 G90
N2 G21
(Spindle Speed      = 5000 RPM)
(Tool               = 3)
(Toolpath name      = Boring_2)
(Head angle         = 30 deg)
N3 G00 X-25. Y10. Z16.
(First Toolpath Point)
(Cutting Move Starts)
N4 X-25. Y10. Z16.
N5 X-25. Y10. Z6.
N6 X-25. Y10. Z5.
N7 G01 X-25. Y10. Z-15. F399.999
(Lead Out Move Starts)
N8 X-25. Y10. Z5.
N9 G00 X-25. Y10. Z6. F1000
(Cutting Move Starts)
N10 X25. Y10. Z6.
N11 X25. Y10. Z6.
N12 X25. Y10. Z5.
N13 G01 X25. Y10. Z-15. F399.999
(Lead Out Move Starts)
N14 X25. Y10. Z5.
N15 G00 X25. Y10. Z6. F1000
(Rapid Move Starts)
N16 X25. Y10. Z16.
N17 M30
%
