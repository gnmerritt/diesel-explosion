#![feature(plugin, custom_derive, proc_macro_hygiene, decl_macro)]
extern crate diesel;
#[macro_use] extern crate rocket;
#[macro_use] extern crate rocket_contrib;

use rocket::http::Cookies;
use rocket::{ignite, Rocket};
use diesel::PgConnection;

#[database("db")]
pub struct DbConn(PgConnection);

#[post("/hello")]
fn login(_db: DbConn, _cookies: Cookies) -> Result<(), ()> {
    Ok(())
}

pub fn rocket() -> Rocket {
    ignite()
    .attach(DbConn::fairing())
    .mount("/api", routes![login])
}


#[cfg(test)]
mod test {
    use super::rocket;
    use rocket::local::Client;
    use rocket::http::{ContentType, Status};

    fn client() -> Client {
        Client::new(rocket()).expect("valid rocket instance")
    }

    #[test]
    fn test_world() {
        let client = client();
        let response = client.post("/api/hello")
            .header(ContentType::JSON)
            .body("{}".to_string())
            .dispatch();
         assert_eq!(response.status(), Status::Ok);
    }

    #[test]
    fn upload_missing_endpoint() {
        let client = client();
        let response = client.get("/api/some-other-endpoint").dispatch();
        assert_eq!(response.status(), Status::NotFound);
    }
}
