let replay () : unit =
  [%mel.raw
    {| (function(){ if (window.__SOLID_ML_EVENT_REPLAY__ && window.__SOLID_ML_EVENT_REPLAY__.replay) { window.__SOLID_ML_EVENT_REPLAY__.replay(); } })() |}]
