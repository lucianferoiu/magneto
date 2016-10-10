defmodule UserDAO do
  import Magneto.Operations
  alias Models.User

  def ddl do
    Magneto.list
    create User
    describe User
    destroy User
  end

  def dml do
    # get
    # user = User.with uuid, and: timestamp
    user = get User, with: uuid, and: timestamp
    user = get User, hash: uuid, range: timestamp
    # user = User.by(uuid, timestamp)
    # user = User.get hash: uuid, range: timestamp

    # data access
    user.email
    user.name
    user.keys # syntetic
    user.hash # syntetic

    #put
    User.put(values_map_including_keys)
    put User, values: values_map_including_keys


    #scan
    users = scan u in User, where: u.email not nil and u.age > 18 and u.address.city == ^home_city
    other_users = scan u in User, where: u.enabled == true, select: u.email
    last_user = List.last(other_users)
    scan u in User, where: u.enabled == true, limit: 100, start: ^last_user.keys

    #query
    voters = query u in UsersOfAge, for: "Toto",  where: u.age > 18


    #transaction (two-phase commit)
    transaction do  #based on exceptions?
      user = get User, with: uuid, and: time_now
      put Player, values: %{uuid: user.uuid, game: current_game, started_on: time_now}
      commit
      except not_found: User, do: rollback
      except stale: Player, do: retry :once, then: rollback
    end

  end

end
