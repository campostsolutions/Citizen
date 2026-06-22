{
   "controller" : {
      "synced_configuration" : {
         "head_info_part_id" : "head",
         "max_block_processing_speed" : 0,
         "max_normal_speed" : 0,
         "parts" : {
            "U" : {
               "coordinate" : 0,
               "max_normal_speed" : 21600,
               "max_rapid_speed" : 0,
               "preference" : "no preference",
               "reset" : "never",
               "reversed" : false,
               "tcp" : true,
               "wrap_around_at_max" : 360,
               "wrap_around_at_min" : -360,
               "zero_position_offset" : 0
            },
            "X" : {
               "coordinate" : 0,
               "max_normal_speed" : 0,
               "max_rapid_speed" : 0,
               "preference" : "no preference",
               "reset" : "never",
               "reversed" : false,
               "tcp" : true,
               "zero_position_offset" : 0
            },
            "Y" : {
               "coordinate" : 1,
               "max_normal_speed" : 0,
               "max_rapid_speed" : 0,
               "preference" : "no preference",
               "reset" : "never",
               "reversed" : false,
               "tcp" : true,
               "zero_position_offset" : 0
            },
            "Z" : {
               "coordinate" : 2,
               "max_normal_speed" : 0,
               "max_rapid_speed" : 0,
               "preference" : "no preference",
               "reset" : "never",
               "reversed" : false,
               "tcp" : true,
               "zero_position_offset" : 0
            }
         },
         "table_part_id" : "table"
      }
   },
   "fusion" : {
      "default" : {
         "guid" : "a17518f1-4b9f-65ee-0951-018ff7dd33bc"
      }
   },
   "general" : {
      "capabilities" : [ "milling" ],
      "description" : "A_aroundX_table",
      "minimumRevision" : 45805
   },
   "kinematics" : {
      "default" : {
         "conventions" : {
            "rotation" : "right-handed"
         },
         "parts" : [
            {
               "id" : "static_0",
               "type" : "static"
            },
            {
               "control" : "driven",
               "direction" : [ 1, 0, 0 ],
               "id" : "X",
               "name" : "X",
               "parts" : [
                  {
                     "control" : "driven",
                     "direction" : [ 0, 1, 0 ],
                     "id" : "Y",
                     "name" : "Y",
                     "parts" : [
                        {
                           "control" : "driven",
                           "direction" : [ 0, 0, 1 ],
                           "id" : "Z",
                           "name" : "Z",
                           "parts" : [
                              {
                                 "attach_frame" : {
                                    "point" : [ 0, 0, 0 ],
                                    "x_direction" : [ 1, -0, 0 ],
                                    "z_direction" : [ 0, 0, 1 ]
                                 },
                                 "id" : "head",
                                 "spindle" : {
                                    "max_speed" : 0,
                                    "min_speed" : 0
                                 },
                                 "tool_station" : {
                                    "coolants" : [
                                       "air",
                                       "air_through_tool",
                                       "flood",
                                       "flood_mist",
                                       "flood_through_tool",
                                       "mist",
                                       "suction",
                                       "through_tool"
                                    ],
                                    "max_tool_diameter" : 0,
                                    "max_tool_length" : 0
                                 },
                                 "type" : "head"
                              }
                           ],
                           "type" : "linear"
                        }
                     ],
                     "type" : "linear"
                  }
               ],
               "type" : "linear"
            },
            {
               "axis_of_rotation" : {
                  "direction" : [ -1, -0, -0 ],
                  "point" : [ 0, 0, 0 ]
               },
               "control" : "driven",
               "id" : "U",
               "name" : "A",
               "parts" : [
                  {
                     "attach_frame" : {
                        "point" : [ 0, 0, 0 ],
                        "x_direction" : [ 1, -0, 0 ],
                        "z_direction" : [ 0, 0, 1 ]
                     },
                     "id" : "table",
                     "type" : "table"
                  }
               ],
               "type" : "rotary"
            }
         ],
         "units" : {
            "angle" : "degrees",
            "length" : "mm"
         }
      }
   },
   "machining" : {
      "default" : {
         "feedrate_ratio" : 1,
         "tool_change_time" : 15
      }
   },
   "multiaxis" : {
      "default" : {
         "singularity" : {
            "adjust" : true,
            "angle" : 0.17453292519943295,
            "cone" : 0.05235987755982989,
            "linearization_tolerance" : 0.040000000000000001,
            "method" : "rotary",
            "tolerance" : 0.040000000000000001
         },
         "virtual_tool_tip" : false
      }
   },
   "tooling" : {
      "default" : {
         "has_tool_changer" : true,
         "number_of_tools" : 100,
         "supports_tool_preload" : true
      }
   }
}

