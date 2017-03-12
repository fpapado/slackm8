module Update exposing (..)

import Random
import String
import Http
import Task
import Json.Decode as Json
import Json.Decode.Pipeline exposing (decode, optional, required)
import Model exposing (Member, Model)
import Shuffle exposing (shuffle)
import Split exposing (split)
import Helpers exposing (dasherize, filterMembers)
import Ports


type Msg
    = Close
    | CreateChannelResult (Result Http.Error String)
    | FetchMembers
    | FetchMembersResult (Result Http.Error (Maybe (List Member)))
    | InviteMemberFail Http.Error
    | InviteMembersToChannels
    | InviteMemberSuccess Bool
    | InviteMemberResult (Result Http.Error Bool)
    | CreateChannelAddMemberResult (Result Http.Error (List Bool))
    | SetLimit Int
    | SetTitle String
    | Shuffle
    | Split (List Member)
    | StoreToken String



-- update


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Close ->
            ( { model
                | error = Nothing
                , success = False
              }
            , Cmd.none
            )

        CreateChannelResult result ->
            case result of
                Ok res ->
                    model
                        ! []

                Err err ->
                    handleHttpError err model

        FetchMembers ->
            let
                model_ =
                    { model | isLoading = True }
            in
                ( model_, fetchAllMembers model_.token )

        FetchMembersResult (Ok result) ->
            let
                filtered =
                    filterMembers result
            in
                ( { model
                    | isLoading = False
                    , limit = List.length (Maybe.withDefault [] result)
                    , team = Just filtered
                    , error = Nothing
                  }
                , Random.generate Split (shuffle filtered)
                )

        FetchMembersResult (Err err) ->
            handleHttpError err model

        InviteMemberFail err ->
            handleHttpError err model

        InviteMembersToChannels ->
            model
                ! List.indexedMap (\i grp -> createChannelAddUsers i model.token model.title grp)
                    (Maybe.withDefault [] model.groups)

        InviteMemberSuccess bool ->
            ( { model
                | error = Nothing
                , success = True
              }
            , Cmd.none
            )

        SetLimit num ->
            let
                model_ =
                    { model | limit = num }
            in
                ( model_, Ports.modelChange model_ )

        SetTitle title ->
            let
                default =
                    if title == "" then
                        "Room"
                    else
                        title

                transformedTitle =
                    default
                        |> String.toLower
                        |> dasherize

                model_ =
                    { model | title = transformedTitle }
            in
                ( model_, Ports.modelChange model_ )

        Shuffle ->
            case model.team of
                Just team ->
                    ( model, Random.generate Split (shuffle team) )

                Nothing ->
                    ( model, Cmd.none )

        Split list ->
            let
                model_ =
                    { model | groups = Just (split model.limit list) }
            in
                ( model_, Ports.modelChange model_ )

        StoreToken token ->
            ( { model | token = token }, Cmd.none )

        -- Placeholders
        InviteMemberResult res ->
            model ! []

        CreateChannelAddMemberResult result ->
            case result of
                Ok bools ->
                    { model | error = Nothing, success = True } ! []

                Err err ->
                    handleHttpError err model



-- handleHttpError
-- Handle a http error


handleHttpError : Http.Error -> Model -> ( Model, Cmd Msg )
handleHttpError err model =
    case err of
        Http.Timeout ->
            ( { model
                | error = Just "Timeout"
                , isLoading = False
              }
            , Cmd.none
            )

        Http.NetworkError ->
            ( { model
                | error = Just "Network Error"
                , isLoading = False
              }
            , Cmd.none
            )

        Http.BadPayload error resp ->
            ( { model
                | error = Just error
                , isLoading = False
              }
            , Cmd.none
            )

        Http.BadStatus resp ->
            let
                err =
                    resp.status.message
            in
                ( { model
                    | error = Just err
                    , isLoading = False
                  }
                , Cmd.none
                )

        Http.BadUrl error ->
            ( { model
                | error = Just error
                , isLoading = False
              }
            , Cmd.none
            )



-- fetchAllMembers
-- method: GET
-- Retrieve all Members from a team (defaults to *** team)


fetchAllMembers : String -> Cmd Msg
fetchAllMembers token =
    let
        req =
            fetchAllMembersReq token
    in
        Http.send FetchMembersResult req


fetchAllMembersReq : String -> Http.Request (Maybe (List Member))
fetchAllMembersReq token =
    let
        url =
            "https://slack.com/api/users.list?token=" ++ token
    in
        Http.get url decodeMembersResponse



-- decodeMembersResponse
-- pluck out the members array from the fetchAllMembers response
-- and iterate required data using decodeMembers


decodeMembersResponse : Json.Decoder (Maybe (List Member))
decodeMembersResponse =
    Json.maybe <| Json.at [ "members" ] (Json.list decodeMembers)



-- decodeMembers
-- pluck out the id, team_id, name and real_name for each member


decodeMembers : Json.Decoder Member
decodeMembers =
    decode Member
        |> required "id" Json.string
        |> required "team_id" Json.string
        |> required "name" Json.string
        |> required "real_name" Json.string
        |> required "profile" decodeSmlAvatar
        |> required "profile" decodeLrgAvatar



-- decodeLrgAvatar
-- pluck the 'image_32' from profile


decodeLrgAvatar : Json.Decoder String
decodeLrgAvatar =
    Json.at [ "image_32" ] Json.string



-- decodeSmlAvatar
-- pluck the 'image_24' from profile


decodeSmlAvatar : Json.Decoder String
decodeSmlAvatar =
    Json.at [ "image_24" ] Json.string



-- createChannelAddUsers
-- Combines the Http requests of createChannelReq and inviteMemberReq.
-- to create a channel and add users in the specified group to it


createChannelAddUsers : Int -> String -> String -> List Member -> Cmd Msg
createChannelAddUsers idx token title group =
    -- NOTE: this works, but all the tasks either fail or succeed together
    -- might want to emit a bunch of Cmds instead
    -- The 0.18 Http library does not have chaining (yet), so we must
    -- convert to Tasks
    let
        createChannelTask =
            Http.toTask (createChannelReq idx token title)

        inviteEachMember =
            \channel_id -> List.map (inviteMemberTask channel_id) group

        inviteMemberTask =
            \channel_id user -> Http.toTask (inviteMemberReq token channel_id user.id)

        chain =
            createChannelTask
                |> Task.andThen (\channel_id -> Task.sequence (inviteEachMember channel_id))
    in
        Task.attempt CreateChannelAddMemberResult chain



-- createChannel
-- create a channel for each group
-- passing in `title` as the channel name
-- which will return the room id from `decodeCreateChannelResponse`


createChannel : Int -> String -> String -> Cmd Msg
createChannel idx token title =
    let
        req =
            createChannelReq idx token title
    in
        Http.send CreateChannelResult req


createChannelReq : Int -> String -> String -> Http.Request String
createChannelReq idx token title =
    let
        url =
            "https://slack.com/api/channels.create?token="
                ++ token
                ++ "&name="
                ++ title
                ++ "-"
                ++ toString (idx + 1)
    in
        Http.post url Http.emptyBody decodeCreateChannelResponse



-- decodeCreateChannelResponse
-- return channel id from createChannel response


decodeCreateChannelResponse : Json.Decoder String
decodeCreateChannelResponse =
    Json.at [ "channel", "id" ] Json.string



-- inviteMember
-- add a Member to a room using a `room_id` and the Member's name
-- returns a bool from `decodeAddMemberResponse`


inviteMember : String -> String -> String -> Cmd Msg
inviteMember token channel_id user_id =
    let
        req =
            inviteMemberReq token channel_id user_id
    in
        Http.send InviteMemberResult req


inviteMemberReq : String -> String -> String -> Http.Request Bool
inviteMemberReq token channel_id user_id =
    let
        url =
            "https://slack.com/api/channels.invite?token="
                ++ token
                ++ "&channel="
                ++ channel_id
                ++ "&user="
                ++ user_id
    in
        Http.post url Http.emptyBody decodeInviteMemberResponse



-- decodeInviteMemberResponse
-- return 'ok' status from inviteMember response


decodeInviteMemberResponse : Json.Decoder Bool
decodeInviteMemberResponse =
    Json.at [ "ok" ] Json.bool
