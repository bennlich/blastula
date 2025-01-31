#' Send an email message through SMTP
#'
#' Send an email message to one or more recipients via an SMTP server. The email
#' message required as input to `smtp_send()` has to be created by using the
#' [compose_email()] function. The `email_message` object can be previewed by
#' printing the object, where the HTML preview will show how the message should
#' appear in recipients' email clients. We can avoid re-entering SMTP
#' configuration and credentials information by retrieving this information
#' either from disk (with the file generated by use of the
#' [create_smtp_creds_file()] function), or, from the system's key-value store
#' (with the key set by the [create_smtp_creds_key()] function).
#'
#' To send messages, we need access to the **mailsend-go** binary, which is
#' cross-platform and works on Windows, macOS (via Homebrew), and Linux (Debian
#' and RPM packages). Instructions for installation can be found at the
#' [blastula website](https://rich-iannone.github.io/blastula/).
#'
#' @param email The email message object, as created by the [compose_email()]
#'   function. The object's class is `email_message`.
#' @param to A vector of email addresses serving as primary recipients for the
#'   message. For secondary recipients, use the `cc` and `bcc` arguments.
#' @param from The email address of the sender. Often this needs to be the same
#'   email address that is associated with the account actually sending the
#'   message.
#' @param subject The subject of the message, which is usually a brief summary
#'   of the topic of the message.
#' @param cc A vector of email addresses for sending the message as a carbon
#'   copy. This list of for those who are to receive a copy of a message
#'   addressed primarily to another. The list of recipients in the CC list is
#'   visible to all other recipients of the message.
#' @param bcc A vector of email addresses for sending the message as blind
#'   carbon copies. Any email addresses provided here will receive the message
#'   and these email addresses will be concealed from other recipients
#'   (including others on the BCC list).
#' @param credentials One of three credential helper functions must be used
#'   here: (1) [creds()], (2) [creds_key()], or (3) [creds_file()]. The first,
#'   [creds()], allows for a manual specification of SMTP configuration and
#'   credentials within that helper function. This is the most secure method for
#'   supplying credentials as they aren't written to disk. The [creds_key()]
#'   function is used if credentials are stored in the system-wide key-value
#'   store, through use of the [create_smtp_creds_key()] function. The
#'   [creds_file()] helper function relies on a credentials file stored on disk.
#'   Such a file is created using the [create_smtp_creds_file()] function.
#' @param binary_loc An option to supply the location of the `mailsend-go`
#'   binary file should it not be on the system path or in the working
#'   directory.
#' @param echo If set to `TRUE`, the command for sending the message via
#'   `mailsend-go` will be printed to the console. By default, this is `FALSE`.
#' @param dry_run Setting `dry_run` to `TRUE` will return information on the
#'   SMTP sending options. Furthermore, the function will stop short of actually
#'   sending the email message out. By default, however, this is set to `FALSE`.
#' @param creds_file An option to specify a credentials file. As this argument
#'   is deprecated, please consider using `credentials = creds_file(<file>)`
#'   instead.
#'
#' @examples
#' \dontrun{
#' # Before sending out an email through
#' # SMTP, we need an `email_message`
#' # object; for the purpose of a simple
#' # example, we can use the function
#' # `prepare_test_message()` to create
#' # a test version of an email (although
#' # we'd normally use `compose_email()`)
#' email <- prepare_test_message()
#'
#' # The `email` message can be sent
#' # through the `smtp_send()` function
#' # so long as we supply the appropriate
#' # credentials; The following three
#' # examples provide scenarios for both
#' # the creation of credentials and their
#' # retrieval within the `credentials`
#' # argument of `smtp_send()`
#'
#' # (1) Providing the credentials info
#' # directly via the `creds()` helper
#' # (the most secure means of supplying
#' # credentials information)
#'
#' email %>%
#'   smtp_send(
#'     from = "sender@email.com",
#'     to = "recipient@email.com",
#'     credentials = creds(
#'       provider = "gmail",
#'       user = "sender@email.com")
#'   )
#'
#' # (2) Using a credentials key (with
#' # the `create_smtp_creds_key()` and
#' # `creds_key()` functions)
#'
#' create_smtp_creds_key(
#'  id = "gmail",
#'  user = "sender@email.com",
#'  provider = "gmail"
#'  )
#'
#' email %>%
#'   smtp_send(
#'     from = "sender@email.com",
#'     to = "recipient@email.com",
#'     credentials = creds_key(
#'       "gmail"
#'       )
#'   )
#'
#' # (3) Using a credentials file (with
#' # the `create_smtp_creds_file()` and
#' # `creds_file()` functions)
#'
#' create_smtp_creds_file(
#'  file = "gmail_secret",
#'  user = "sender@email.com",
#'  provider = "gmail"
#'  )
#'
#' email %>%
#'   smtp_send(
#'     from = "sender@email.com",
#'     to = "recipient@email.com",
#'     credentials = creds_file(
#'       "gmail_secret")
#'   )
#' }
#'
#' @export
smtp_send <- function(email,
                      to,
                      from,
                      subject = NULL,
                      cc = NULL,
                      bcc = NULL,
                      credentials = NULL,
                      binary_loc = NULL,
                      echo = FALSE,
                      dry_run = FALSE,
                      creds_file = "deprecated") {

  # Verify that the `message` object
  # is of the class `email_message`
  if (!inherits(email, "email_message")) {
    stop("The object provided in `email` must be an ",
         "`email_message` object.\n",
         " * This can be created with the `compose_email()` function.",
         call. = FALSE)
  }

  # Establish the location of the `mailsend-go` binary
  if (is.null(binary_loc)) {
    binary_loc <- find_binary("mailsend-go")
    if (is.null(binary_loc)) {
      stop("The binary file `mailsend-go` is not in the system path or \n",
           "in the working directory:\n",
           " * install `mailsend-go` using the instructions at ",
           "https://github.com/muquit/mailsend-go#downloading-and-installing",
           call. = FALSE)
    }
  }

  # If the user provides a path to a creds file in the `creds_file`
  # argument, upgrade that through the `creds_file()` helper function
  # and provide a warning about soft deprecation
  if (!missing(creds_file)) {
    credentials <- creds_file(creds_file)
    warning("The `creds_file` argument is deprecated:\n",
            " * please consider using `credentials = creds_file(\"", creds_file,
            "\")` instead")
  }

  # If nothing is provided in `credentials`, stop the function
  # and include a message about which credential helpers could
  # be used
  if (is.null(credentials)) {
    stop("SMTP credentials must be supplied to the `credentials` argument.\n",
         "We can use either of these three helper functions for this:\n",
         " * `creds_key()`: uses information stored in the system's key-value ",
         "store (have a look at `?creds_key`)\n",
         " * `creds_file()`: takes credentials stored in an on-disk file ",
         "(use `?creds_file` for further info)\n",
         " * `creds()`: allows for manual specification of SMTP credentials",
         call. = FALSE)
  }

  # If whatever is provided to `credentials` does not have a
  # `blastula_creds` class, determine whether that value is a
  # single-length character vector (which is upgraded through
  # the `creds_file()` function); if it's anything else, stop
  # the function with a message
  if (!inherits(credentials, "blastula_creds")) {
    if (is.character(credentials) && length(credentials) == 1) {

      credentials <- creds_file(file = credentials)

    } else {
      stop("The value for `credentials` must be a `blastula_creds` object\n",
           "* see the article in `?creds` for information on this",
           call. = FALSE)
    }
  }

  # Create a temporary file with the `html` extension
  tempfile_ <- tempfile(fileext = ".html")

  # Reverse slashes on Windows filesystems
  tempfile_ <-
    tempfile_ %>%
    tidy_gsub("\\\\", "/")

  # Write the inlined HTML message out to a file
  email$html_str %>% writeLines(con = tempfile_, useBytes = TRUE)

  # Remove the file after the function exits
  on.exit(file.remove(tempfile_))

  # Normalize `subject` so that a `NULL` value becomes an empty string
  subject <- subject %||% ""

  # Create comma-separated addresses for
  # `to`, `cc`, and `bcc`
  to <- make_address_list(to)
  cc <- make_address_list(cc)
  bcc <- make_address_list(bcc)

  # Set the `ssl` flag depending on the options provided
  if (credentials$use_ssl) {
    ssl_opt <- no_options()
  } else {
    ssl_opt <- no_arg()
  }

  # Set the `sender_name` to `no_arg()` if not provided
  sender_name_opt <- credentials$sender_name %||% no_arg()

  # Collect arguments and options for for `processx::run()`
  # as a list
  run_args <-
    list(
      `-sub` = subject,
      `-smtp` = credentials$host,
      `-port` = credentials$port %>% as.character(),
      `-ssl` = ssl_opt,
      `auth` = no_options(),
      `-user` = credentials$user,
      `-pass` = credentials$password,
      `-fname` = sender_name_opt,
      `-from` = from,
      `-to` = to,
      `-cc` = cc,
      `-bcc` = bcc,
      `attach` = no_options(),
      `-file` = tempfile_,
      `-mime-type` = "text/html",
      `-inline` = no_options()
    )

  # Create the vector of arguments related to file attachments
  attachment_args_vec <- create_attachment_args_vec(email = email)

  # Clean up arguments and options; create the vector that's
  # needed for `processx::run()`
  run_args <-
    run_args %>%
    prune_args() %>%
    create_args_opts_vec() %>%
    append_attachment_args_vec(attachment_args_vec = attachment_args_vec)

  if (echo) {

    cmd_str <- run_args
    cmd_str[which(run_args == "-pass")[1] + 1] <- "*****"
    cmd_str <- paste(binary_loc, paste0(cmd_str, collapse = " "))

    message(
      "The command for sending the email message is:\n\n",
      cmd_str, "\n"
    )
  }

  if (dry_run) {

    message("This was a dry run, the email message was NOT sent.")

    return(invisible())

  } else {

    # Send out email via `processx::run()` and
    # assign the result
    send_result <-
      processx::run(
        command = binary_loc,
        args = run_args,
        error_on_status = FALSE
      )

    if (send_result$status == 0) {
      message("The email message was sent successfully.\n")
    } else {
      message("The email message was NOT successfully sent.\n")
      message(send_result$stderr)
    }
  }
}
