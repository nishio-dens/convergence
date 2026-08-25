DROP TABLE IF EXISTS paper_authors;
DROP TABLE IF EXISTS papers;
DROP TABLE IF EXISTS authors;

CREATE TABLE authors (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name varchar(110) NOT NULL,
  age int NOT NULL,
  created_at datetime,
  updated_at datetime
);
CREATE INDEX index_authors_on_created_at ON authors (created_at);

CREATE TABLE papers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  slug varchar(255) NOT NULL,
  title1 varchar(300) NOT NULL,
  title2 varchar(300) NOT NULL,
  description text,
  edition_number int NOT NULL DEFAULT 0,
  published_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE UNIQUE INDEX index_papers_on_slug ON papers (slug);

CREATE TABLE paper_authors (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  paper_id int NOT NULL,
  author_id int NOT NULL,
  CONSTRAINT paper_authors_author_id_fk FOREIGN KEY (author_id) REFERENCES authors (id),
  CONSTRAINT paper_authors_paper_id_fk FOREIGN KEY (paper_id) REFERENCES papers (id)
);
