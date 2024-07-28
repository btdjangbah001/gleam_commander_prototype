import gleam/io
import gleam/dict

pub type ArgType {
  F
  A
}

pub type Arg {
  Flag(long: String, short: String, name: String)
  Arg(long: String, short: String, validator: fn(String)->Bool, name: String)
}

pub type ArgsParser {
  ArgsParser(options: List(Arg))
}

pub type Args = dict.Dict(String, #(String, ArgType))

pub fn main() {
  let args = [
    Arg(long: "--port", short: "-p", validator: fn(_x: String){True}, name: "replicaof"), 
    Arg(long: "--replicaof", short: "-r", validator: fn(_x: String){True}, name: "port"), 
    Flag(long: "--cache", short: "-c", name: "cache")]

  let options = ArgsParser(options: args)

  let args = ["--replicaof", "some master", "-c", "-p", "9001"]

  let res = load(args, options)
  io.debug(res)
  //dict.from_list([#("cache", #("", F)), #("port", #("some master", A)), #("replicaof", #("9001", A))])
  io.debug(get(res, "port")) // Ok(#("some master", A))
  io.debug(get(res, "replicaof")) // Ok(#("9001", A))
  io.debug(get(res, "cache")) // Ok(#("", F))

  // i didn't want to create different methods for getting a flag and an arg so i added type info to what get returned, whether arg or flag so that the user can decide what to do themselved
}

fn get(args: Args, name: String) -> Result(#(String, ArgType), Nil) {
  dict.get(args, name)
}

fn load(args: List(String), options: ArgsParser){
  let ops = create_options_map(options.options, dict.new())
  args
    |> load_tail(ops, dict.new())
}

fn load_tail(args: List(String), ops: dict.Dict(String, Arg), acc: Args){
  case args {
    [head, ..tail] -> {
      case dict.has_key(ops, head) {
        True -> {
          case dict.get(ops, head) {
            Ok(value) -> {
              case value {
                Flag(_, _, name) -> {
                  dict.insert(acc, name, #("", F))
                    |> load_tail(tail, ops, _)
                }
                Arg(_, _, validator, name) -> {
                  case tail {
                    [] -> panic as {"expected a value after " <> head <> " but got end of args"}
                    [head, ..tail] -> {
                      case validator(head) {
                        True -> {
                          dict.insert(acc, name, #(head, A))
                            |> load_tail(tail, ops, _)
                        }
                        False -> {
                          panic as {"value failed validation"}
                        }
                      }
                      
                    }
                  }
                }
              }
            }
            Error(_) -> panic as {head <> " is guaranteed to exist after has_key check"}
          }
        }
        _ -> panic as {"Error unknown arg " <> head}
      }
    }
    _ -> acc
  }
}

fn create_options_map(options: List(Arg), acc: dict.Dict(String, Arg)) -> dict.Dict(String, Arg) {
  case options {
    [] -> acc
    [head, ..tail] -> {
      dict.insert(acc, head.long, head)
      |> dict.insert(head.short, head)
      |> create_options_map(tail, _)
    }
  }
}
