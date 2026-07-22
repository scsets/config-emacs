-- Filename: tidy-org.lua
-- Description: Pandoc Lua filter for tidy Emacs-style Org output
-- Author: SCS
-- Copyright: Copyright (C) 2026, SCS, all rights reserved.
-- Created: 2026-07-22 Wed 14:09
-- Version: 0.1.0
-- Last-Updated: 2026-07-22 Wed 14:09
-- Update #: 0
--
-- Clear header identifiers so the Org writer does not emit
-- :PROPERTIES: / :CUSTOM_ID: drawers. Unwrap Div nodes so empty
-- attribute wrappers do not appear in the Org text.

function Header (elem)
  elem.identifier = ""
  elem.attributes = {}
  elem.classes = {}
  return elem
end

function Div (elem)
  return elem.content
end
