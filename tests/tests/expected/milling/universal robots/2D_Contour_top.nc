%
(MYCOMMENT)
(G-code output for Universal Robots' Remote TCP & Toolpath URCap)
(Compatible with Polyscope 5.11.4 and above)
N1 G90
N2 G21
(Spindle Speed      = 6000 RPM)
(Tool               = 8)
(Toolpath name      = 2D_Contour_top)
(Head angle         = 30 deg)
N3 G00 X-1.5 Y-1.27 Z16.24
(First Toolpath Point)
N4 X-1.5 Y-1.27 Z6.08
(Plunge Move Starts)
N5 G01 X-1.5 Y-1.27 Z2. F499.999
N6 X-1.5 Y-1.27 Z-3.73
(Lead In Move Starts)
N7 X-1.128 Y-1.27 Z-4.628 F1000.001
N8 X-0.23 Y-1.27 Z-5.
N9 X1.04 Y-1.27 Z-5.
N10 G03 X2.31 Y0. Z-5. I0. J1.27
(Cutting Move Starts)
N11 G03 X-2.31 Y0. Z-5. I-2.31 J0.
N12 G03 X2.31 Y0. Z-5. I2.31 J0.
(Lead Out Move Starts)
N13 G03 X1.04 Y1.27 Z-5. I-1.27 J0.
N14 G01 X-0.23 Y1.27 Z-5.
N15 X-1.128 Y1.27 Z-4.628
N16 X-1.5 Y1.27 Z-3.73
(Rapid Move Starts)
N17 G00 X-1.5 Y1.27 Z16.24 F1000
N18 M30
%
