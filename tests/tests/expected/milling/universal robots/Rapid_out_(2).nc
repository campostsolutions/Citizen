%
(MYCOMMENT)
(G-code output for Universal Robots' Remote TCP & Toolpath URCap)
(Compatible with Polyscope 5.11.4 and above)
N1 G90
N2 G21
(Spindle Speed      = 5000 RPM)
(Tool               = 3)
(Toolpath name      = Rapid_out_2)
(Head angle         = 30 deg)
N3 G00 X-25. Y10. Z16. F1000
(First Toolpath Point)
(Cutting Move Starts)
N4 X-25. Y10. Z16.
N5 X-25. Y10. Z6.
N6 X-25. Y10. Z5.
N7 G01 X-25. Y10. Z-16.535 F399.999
N8 G00 X-25. Y10. Z6. F1000
N9 X25. Y10. Z6.
N10 X25. Y10. Z6.
N11 X25. Y10. Z5.
N12 G01 X25. Y10. Z-16.535 F399.999
N13 G00 X25. Y10. Z6. F1000
(Rapid Move Starts)
N14 X25. Y10. Z16.
N15 M30
%
