module Update exposing (..)

import Set exposing (Set)
import Char
import Time exposing (Time)
import Keyboard exposing (KeyCode)

import Model exposing (..)
import Model.Ui exposing (..)
import Model.Scene exposing (..)
import Subscription exposing (..)

import Debug exposing (log)
------------------------------------------------------------------------- UPDATE

update : Msg -> Model -> (Model, Cmd Msg)
update action ({ui,scene} as model) =
  case action of
    ResizeWindow dimensions ->
      ({ model | ui = { ui | windowSize = dimensions } }, Cmd.none)

    Tick delta ->
      let
          player' = stepPlayer delta ui scene.player
          scene' = { scene | player = player' }
          screen' = if player'.position.y > 1 then GameoverScreen else PlayScreen
          ui' = { ui | screen = screen' }
      in
          ({ model | scene = scene', ui = ui' }, Cmd.none)

    KeyChange pressed keycode ->
      (handleKeyChange pressed keycode model, Cmd.none)

    StartGame ->
      (freshGame ui, Cmd.none)

    NoOp ->
      (model, Cmd.none)


stepPlayer : Time -> Ui -> Player -> Player
stepPlayer delta {pressedKeys} ({position,velocity} as player) =
  let
      delta = delta * 0.8 -- tweak the overall pace of gameplay
      directionX = if keyPressed (Char.toCode 'A') pressedKeys then
                     -1
                   else if keyPressed (Char.toCode 'D') pressedKeys then
                     1
                   else
                     0
      ax = directionX * 0.0000019
      vx = velocity.x + ax*delta |> friction delta
      vy = velocity.y |> (gravity delta)
      airborne = position.y + vy*delta < icePosY
      stepFn = if airborne then
                 fly
               else if inBounds position.x then
                 walk
               else
                 fall
      (x', y', vx', vy') = stepFn delta position.x position.y vx vy
      position' = { position | x = x'
                             , y = y' }
      velocity' = { velocity | x = vx'
                             , y = vy' }
  in
      { player
      | position = position'
      , velocity = velocity' }


fly : Time -> Float -> Float -> Float -> Float -> (Float,Float,Float,Float)
fly delta x y vx vy =
  (x+vx*delta, y+vy*delta, vx, vy)


walk : Time -> Float -> Float -> Float -> Float -> (Float,Float,Float,Float)
walk delta x y vx vy =
  let
      x = x + vx*delta
      y = icePosY
      vy = 0
  in
      (x, y, vx, vy)


fall : Time -> Float -> Float -> Float -> Float -> (Float,Float,Float,Float)
fall delta x y vx vy =
  let
      y = y + vy*delta
      x = x + vx*delta
      isLeftSide = x<0.5
      x' = if y<icePosY+playerRadius then
             rollOffEdge x y isLeftSide
           else
             keepOutOfBounds x
  in
      (x', y, vx, vy)


inBounds : Float -> Bool
inBounds x =
  x>=icePosX && x<=iceRightEdgeX


friction : Time -> Float -> Float
friction delta vx =
  vx / (1 + 0.0018*delta)


jump : Player -> Player
jump ({position,velocity} as player) =
  let
      vy = if position.y==icePosY then -0.001 else velocity.y
      velocity' = { velocity | y = vy }
  in
      { player | velocity = velocity' }


gravity : Time -> Float -> Float
gravity delta vy =
  vy + 0.000003 * delta


rollOffEdge : Float -> Float -> Bool -> Float
rollOffEdge x y isLeftSide =
  let
      edgePosX = if isLeftSide then icePosX else iceRightEdgeX
      increment = 0.001 * (if isLeftSide then -1 else 1)
  in
      if distance (x,y-playerRadius) (edgePosX,icePosY) > playerRadius then
        x
      else
        rollOffEdge (x + increment) y isLeftSide


keepOutOfBounds : Float -> Float
keepOutOfBounds x =
  if x<0.5 then
     min x (icePosX-playerRadius)
  else
     max x (iceRightEdgeX+playerRadius)


handleKeyChange : Bool -> KeyCode -> Model -> Model
handleKeyChange pressed keycode ({scene,ui} as model) =
  let
      fn = if pressed then Set.insert else Set.remove
      pressedKeys' = fn keycode ui.pressedKeys
  in
      case ui.screen of
        PlayScreen ->
          let
              ui' = { ui | pressedKeys = pressedKeys' }
              player' = if freshKeyPress 'W' ui.pressedKeys pressedKeys' then
                           jump scene.player
                         else
                           scene.player
              scene' = { scene |  player = player' }
          in
              { model | ui = ui', scene = scene' }

        GameoverScreen ->
          if freshKeyPress ' ' ui.pressedKeys pressedKeys' then
            freshGame ui
          else
            model

        _ ->
          model


freshKeyPress : Char -> Set KeyCode -> Set KeyCode -> Bool
freshKeyPress char previouslyPressedKeys currentlyPressedKeys =
  let
      pressed = keyPressed (Char.toCode char)
  in
      pressed currentlyPressedKeys && not (pressed previouslyPressedKeys)
