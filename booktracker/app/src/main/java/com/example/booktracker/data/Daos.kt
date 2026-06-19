package com.example.booktracker.data

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface BookDao {
    @Query("SELECT * FROM books ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<Book>>

    @Query("SELECT * FROM books WHERE id = :id")
    fun observeById(id: Long): Flow<Book?>

    @Query("SELECT * FROM books WHERE id = :id")
    suspend fun getById(id: Long): Book?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(book: Book): Long

    @Update
    suspend fun update(book: Book)

    @Delete
    suspend fun delete(book: Book)
}

@Dao
interface QuoteDao {
    @Query("SELECT * FROM quotes ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<Quote>>

    @Query("SELECT * FROM quotes WHERE bookId = :bookId ORDER BY createdAt DESC")
    fun observeForBook(bookId: Long): Flow<List<Quote>>

    @Query("SELECT COUNT(*) FROM quotes")
    fun observeCount(): Flow<Int>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(quote: Quote): Long

    @Update
    suspend fun update(quote: Quote)

    @Delete
    suspend fun delete(quote: Quote)
}

@Dao
interface ReadingLogDao {
    @Query("SELECT * FROM reading_logs ORDER BY dateEpochDay ASC")
    fun observeAll(): Flow<List<ReadingLog>>

    @Insert
    suspend fun insert(log: ReadingLog): Long
}
