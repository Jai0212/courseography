{-# LANGUAGE ScopedTypeVariables, OverloadedStrings #-}

module Database.CourseQueries (queryCourse, 
                              returnCourse,
                              allCourses) where

import Database.Persist
import Database.Persist.Sqlite
import Database.Tables as Tables
import JsonResponse
import Database.JsonParser
import Happstack.Server
import Data.List
import qualified Data.Text as T
import qualified Data.Aeson as Aeson
import Control.Monad.IO.Class (liftIO)
import WebParsing.ParsingHelp

-- | Queries the database for all information about `course`, constructs a JSON object
-- | representing the course and returns the appropriate JSON response.
queryCourse :: T.Text -> IO Response
queryCourse str = do
  courseJSON <- returnCourse str
  return $ toResponse $ createJSONResponse $ encodeJSON $ Aeson.toJSON courseJSON

-- | Queries the database for all information about `course`, constructs and returns a Course Record.
returnCourse :: T.Text -> IO Course
returnCourse lowerStr =
    runSqlite dbStr $ do
        let courseStr = T.toUpper lowerStr
        sqlCourse :: [Entity Courses] <- selectList [CoursesCode ==. courseStr] []
        sqlLecturesFall :: [Entity Lectures]  <- selectList [LecturesCode  ==. courseStr,
                                                             LecturesSession ==. "F"] []
        sqlLecturesSpring :: [Entity Lectures]  <- selectList [LecturesCode  ==. courseStr,
                                                               LecturesSession ==. "S"] []
        sqlLecturesYear :: [Entity Lectures]  <- selectList [LecturesCode  ==. courseStr,
                                                               LecturesSession ==. "Y"] []
        sqlTutorialsFall :: [Entity Tutorials] <- selectList [TutorialsCode ==. courseStr,
                                                              TutorialsSession ==. "F"] []
        sqlTutorialsSpring :: [Entity Tutorials] <- selectList [TutorialsCode ==. courseStr,
                                                                TutorialsSession ==. "S"] []
        sqlTutorialsYear :: [Entity Tutorials] <- selectList [TutorialsCode ==. courseStr,
                                                                TutorialsSession ==. "Y"] []
        if (null sqlCourse) 
        then (return emptyCourse) 
        else do let course = entityVal $ head sqlCourse
                let fallSession   = buildSession sqlLecturesFall sqlTutorialsFall
                let springSession = buildSession sqlLecturesSpring sqlTutorialsSpring
                let yearSession = buildSession sqlLecturesYear sqlTutorialsYear
                return $ buildCourse fallSession springSession yearSession course
        --return $ toResponse $ createJSONResponse $ encodeJSON $ Aeson.toJSON courseJSON

-- | Builds a Course structure from a tuple from the Courses table.
-- Some fields still need to be added in.
buildCourse :: Maybe Session -> Maybe Session -> Maybe Session -> Courses -> Course
buildCourse fallSession springSession yearSession course =
    Course (coursesBreadth course)
           (coursesDescription course)
           (coursesTitle course)
           (coursesPrereqString course)
           fallSession
           springSession
           yearSession
           (coursesCode course)
           (coursesExclusions course)
           (coursesManualTutorialEnrolment course)
           (coursesDistribution course)
           (coursesPrereqs course)

-- | Builds a Lecture structure from a tuple from the Lectures table.
buildLecture :: Lectures -> Lecture
buildLecture entity =
    Lecture (lecturesExtra entity)
            (lecturesSection entity)
            (lecturesCapacity entity)
            (lecturesTimeStr entity)
            (map timeField (lecturesTimes entity))
            (lecturesInstructor entity)
            (Just (lecturesEnrolled entity))
            (Just (lecturesWaitlist entity))

-- | Builds a Tutorial structure from a tuple from the Tutorials table.
buildTutorial :: Tutorials -> Tutorial
buildTutorial entity =
    Tutorial (tutorialsSection entity)
             (map timeField (tutorialsTimes entity))
             (tutorialsTimeStr entity)

-- | Builds a Session structure from a list of tuples from the Lectures table, and a list of tuples from the Tutorials table.
buildSession :: [Entity Lectures] -> [Entity Tutorials] -> Maybe Tables.Session
buildSession lectures tutorials =
    Just $ Tables.Session (map (buildLecture . entityVal) lectures)
                          (map (buildTutorial . entityVal) tutorials)


-- | Build a list of all course codes in the database
allCourses :: IO Response
allCourses = do
  response <- runSqlite dbStr $ do
      courses :: [Entity Courses] <- selectList [] []
      let codes = map (coursesCode . entityVal) courses
      return $ T.unlines codes
  return $ toResponse response

