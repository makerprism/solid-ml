module Make (Json : Json_intf.S) = struct
  module E = Error
  open Components

  let list_map_result f items =
    let rec loop acc = function
      | [] -> Ok (List.rev acc)
      | item :: rest ->
        match f item with
        | Ok value -> loop (value :: acc) rest
        | Error err -> Error err
    in
    loop [] items

  let get_member json key =
    match Json.member json key with
    | Some value -> Ok value
    | None -> Error (E.Parse_error ("Missing field: " ^ key))

  let get_string json key =
    match get_member json key with
    | Ok value -> Json.to_string value
    | Error err -> Error err

  let get_int json key =
    match get_member json key with
    | Ok value -> Json.to_int value
    | Error err -> Error err

  let rec get_path json = function
    | [] -> Ok json
    | key :: rest ->
      match get_member json key with
      | Ok value -> get_path value rest
      | Error err -> Error err

  let get_path_string json path =
    match get_path json path with
    | Ok value -> Json.to_string value
    | Error err -> Error err

  let user json =
    let open Result in
    let* id = get_int json "id" in
    let* name = get_string json "name" in
    let* username = get_string json "username" in
    let* email = get_string json "email" in
    let* phone = get_string json "phone" in
    let* website = get_string json "website" in
    let* company = get_path_string json [ "company"; "name" ] in
    let* city = get_path_string json [ "address"; "city" ] in
    Ok {
      id;
      name;
      username;
      email;
      phone;
      website;
      company;
      city;
    }

  let post json =
    let open Result in
    let* id = get_int json "id" in
    let* user_id = get_int json "userId" in
    let* title = get_string json "title" in
    let* body = get_string json "body" in
    Ok {
      id;
      user_id;
      title;
      body;
    }

  let comment json =
    let open Result in
    let* id = get_int json "id" in
    let* post_id = get_int json "postId" in
    let* name = get_string json "name" in
    let* email = get_string json "email" in
    let* body = get_string json "body" in
    Ok {
      id;
      post_id;
      name;
      email;
      body;
    }

  let users json =
    match Json.to_list json with
    | Ok list -> list_map_result user list
    | Error err -> Error err

  let posts json =
    match Json.to_list json with
    | Ok list -> list_map_result post list
    | Error err -> Error err

  let comments json =
    match Json.to_list json with
    | Ok list -> list_map_result comment list
    | Error err -> Error err
end
