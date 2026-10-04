import gleeunit
import gleeunit/should
import projects
import ulik

pub fn main() {
  gleeunit.main()
}

pub fn home_route_test() {
  ulik.route_from_url("https://ulik.no/") |> should.equal(ulik.Home)
}

pub fn trailing_slash_route_test() {
  ulik.route_from_url("https://ulik.no/projects/") |> should.equal(ulik.Catalog)
}

pub fn morse_route_test() {
  ulik.route_from_url("/projects/morsekode/sende")
  |> should.equal(ulik.Project(projects.Morse, "sende"))
}

pub fn invalid_route_test() {
  ulik.route_from_url("/projects/morsekode/unknown")
  |> should.equal(ulik.NotFound)
}
